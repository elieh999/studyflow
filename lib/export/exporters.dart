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
  final b = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//StudyFlow//EN')
    ..writeln('CALSCALE:GREGORIAN');

  for (final a in assignments) {
    final course = byId[a.courseId]?.name ?? 'Course';
    final end = a.dueDate.add(const Duration(minutes: 30));
    b
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:assignment-${a.id}@studyflow')
      ..writeln('DTSTAMP:${_icsStamp(now)}')
      ..writeln('DTSTART:${_icsStamp(a.dueDate)}')
      ..writeln('DTEND:${_icsStamp(end)}')
      ..writeln('SUMMARY:[$course] ${_esc(a.title)}')
      ..writeln('DESCRIPTION:${_esc(a.description)}')
      ..writeln('END:VEVENT');
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
    b
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:class-${e.id}@studyflow')
      ..writeln('DTSTAMP:${_icsStamp(now)}')
      ..writeln('DTSTART:${_icsStamp(start)}')
      ..writeln('DTEND:${_icsStamp(end)}')
      ..writeln('RRULE:FREQ=WEEKLY;BYDAY=${_byDay[(e.dayOfWeek - 1) % 7]}')
      ..writeln('SUMMARY:$course'
          '${e.location.isNotEmpty ? ' (${_esc(e.location)})' : ''}')
      ..writeln('END:VEVENT');
  }

  b.writeln('END:VCALENDAR');
  return b.toString();
}

DateTime _nextWeekday(DateTime from, int weekday) {
  final today = DateTime(from.year, from.month, from.day);
  var delta = (weekday - today.weekday) % 7;
  if (delta < 0) delta += 7;
  return today.add(Duration(days: delta));
}

String _esc(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll('\n', '\\n');

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
          pw.Text('StudyFlow — weekly report',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              'Week of ${df.format(weekStart)} — generated ${df.format(now)}',
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
                      text:
                          '${byId[e.key]?.name ?? 'Course'}: ${formatDuration(e.value)}'),
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
                      text:
                          '${DateFormat('EEE d MMM, HH:mm').format(a.dueDate)} — '
                          '${byId[a.courseId]?.name ?? ''}: ${a.title}'),
              ],
            ),
        ],
      ),
    ),
  );
  return doc.save();
}
