import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database.dart';
import '../util.dart';

// ---- iCalendar (.ics) export -------------------------------------------------

String _icsStamp(DateTime dt) {
  final u = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

const _byDay = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

String buildIcs({
  required List<Course> courses,
  required List<Assignment> assignments,
  required List<ScheduleEntry> schedule,
  required DateTime now,
}) {
  final byId = {for (final c in courses) c.id: c};
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//StudyFlow//EN',
    'CALSCALE:GREGORIAN',
  ];

  for (final a in assignments) {
    final course = byId[a.courseId]?.name ?? 'Course';
    final end = a.dueDate.add(const Duration(minutes: 30));
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:assignment-${a.id}@studyflow',
      'DTSTAMP:${_icsStamp(now)}',
      'DTSTART:${_icsStamp(a.dueDate)}',
      'DTEND:${_icsStamp(end)}',
      'SUMMARY:[${_esc(course)}] ${_esc(a.title)}',
      'DESCRIPTION:${_esc(a.description)}',
      'END:VEVENT',
    ]);
  }

  for (final e in schedule) {
    final course = byId[e.courseId]?.name ?? 'Course';
    final first = _nextWeekday(now, e.dayOfWeek);
    final sp = e.startTime.split(':');
    final ep = e.endTime.split(':');
    final start = DateTime(first.year, first.month, first.day,
        int.tryParse(sp.first) ?? 9, int.tryParse(sp.last) ?? 0);
    final end = DateTime(first.year, first.month, first.day,
        int.tryParse(ep.first) ?? 10, int.tryParse(ep.last) ?? 0);
    final summary = e.location.isNotEmpty
        ? '${_esc(course)} (${_esc(e.location)})'
        : _esc(course);
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:class-${e.id}@studyflow',
      'DTSTAMP:${_icsStamp(now)}',
      'DTSTART:${_icsStamp(start)}',
      'DTEND:${_icsStamp(end)}',
      'RRULE:FREQ=WEEKLY;BYDAY=${_byDay[(e.dayOfWeek - 1) % 7]}',
      'SUMMARY:$summary',
      'END:VEVENT',
    ]);
  }

  lines.add('END:VCALENDAR');
  // iCalendar requires CRLF line endings and content lines folded at 75 octets.
  return '${lines.map(_foldIcsLine).join('\r\n')}\r\n';
}

DateTime _nextWeekday(DateTime from, int weekday) {
  final today = DateTime(from.year, from.month, from.day);
  var delta = (weekday - today.weekday) % 7;
  if (delta < 0) delta += 7;
  return today.add(Duration(days: delta));
}

String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\n');

// Fold a content line to 75 octets per physical line, never splitting a
// multi-byte character. Continuation lines start with a single space.
String _foldIcsLine(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final buf = StringBuffer();
  var used = 0;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final n = utf8.encode(ch).length;
    if (used + n > 75) {
      buf.write('\r\n ');
      used = 1; // leading space counts toward the 75
    }
    buf.write(ch);
    used += n;
  }
  return buf.toString();
}

// ---- JSON backup / restore ---------------------------------------------------

String buildBackupJson({
  required List<Course> courses,
  required List<Assignment> assignments,
  required List<StudySession> sessions,
  required List<ScheduleEntry> schedule,
  required List<Flashcard> flashcards,
  required List<GradeItem> grades,
  List<Note> notes = const [],
}) {
  Map<String, dynamic> data = {
    'version': 3,
    'courses': courses.map((c) => c.toJson()).toList(),
    'assignments': assignments.map((a) => a.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'schedule': schedule.map((e) => e.toJson()).toList(),
    'flashcards': flashcards.map((f) => f.toJson()).toList(),
    'grades': grades.map((g) => g.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

// ---- Weekly PDF report -------------------------------------------------------

// The bundled PDF font only covers Latin-1. Map anything outside that range to
// a safe character so a note or title in another script can't crash the export.
String _pdfSafe(String s) => String.fromCharCodes(s.runes.map((r) {
      if (r == 9 || r == 10 || r == 13) return 32; // whitespace
      if ((r >= 32 && r <= 126) || (r >= 160 && r <= 255)) return r;
      return 63; // '?'
    }));

Future<Uint8List> buildWeeklyReport({
  required List<Course> courses,
  required List<Assignment> assignments,
  required List<StudySession> sessions,
  required DateTime now,
}) async {
  final weekStart = startOfWeek(now);
  final byId = {for (final c in courses) c.id: c};
  final weekSessions =
      sessions.where((s) => !s.sessionDate.isBefore(weekStart)).toList();
  final totalSecs = weekSessions.fold<int>(0, (t, s) => t + s.duration);

  final perCourse = <int, int>{};
  for (final s in weekSessions) {
    perCourse.update(s.courseId, (v) => v + s.duration,
        ifAbsent: () => s.duration);
  }

  final upcoming = assignments.where((a) => !a.isCompleted).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final completedThisWeek = assignments
      .where((a) => a.isCompleted)
      .length; // total completed (no completion date stored)

  final df = DateFormat('EEE d MMM');
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('StudyFlow weekly report',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              'Week of ${df.format(weekStart)}, generated ${df.format(now)}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Text('Total study time this week: ${formatDuration(totalSecs)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('Study time per course',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (perCourse.isEmpty)
            pw.Text('No study sessions logged this week.')
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final e in perCourse.entries)
                  pw.Bullet(
                      text: _pdfSafe(
                          '${byId[e.key]?.name ?? 'Course'}: ${formatDuration(e.value)}')),
              ],
            ),
          pw.SizedBox(height: 12),
          pw.Text('Assignments completed so far: $completedThisWeek',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('Upcoming deadlines',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (upcoming.isEmpty)
            pw.Text('Nothing pending.')
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final a in upcoming.take(12))
                  pw.Bullet(
                      text: _pdfSafe(
                          '${DateFormat('EEE d MMM, HH:mm').format(a.dueDate)}  '
                          '${byId[a.courseId]?.name ?? ''}: ${a.title}')),
              ],
            ),
        ],
      ),
    ),
  );
  return doc.save();
}
