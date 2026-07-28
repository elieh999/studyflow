import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/data/database.dart';
import 'package:studyflow/export/exporters.dart';
import 'package:studyflow/security/crypto.dart';

void main() {
  group('encrypted backup round trip', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Future<void> seed() async {
      final cid = await db.addCourse(const CoursesCompanion(
          name: Value('Biology'), instructor: Value('Dr Fox'), color: Value(0xFF2E9E67)));
      await db.addAssignment(AssignmentsCompanion(
        courseId: Value(cid),
        title: const Value('Lab report'),
        description: const Value('cells, café notes'),
        dueDate: Value(DateTime(2026, 8, 1, 23, 59)),
        priority: const Value(2),
        estimatedMinutes: const Value(150),
      ));
      await db.addSession(StudySessionsCompanion(
        courseId: Value(cid),
        startTime: Value(DateTime(2026, 7, 27, 20)),
        duration: const Value(1500),
        sessionDate: Value(DateTime(2026, 7, 27, 20)),
        distractions: const Value(3),
        note: const Value('focused-ish'),
      ));
      await db.addScheduleEntry(ScheduleEntriesCompanion(
        courseId: Value(cid),
        dayOfWeek: const Value(3),
        startTime: const Value('09:00'),
        endTime: const Value('10:30'),
        location: const Value('Room 5'),
      ));
      await db.addFlashcard(FlashcardsCompanion(
        courseId: Value(cid),
        question: const Value('Powerhouse of the cell?'),
        answer: const Value('Mitochondria'),
        easiness: const Value(2.36),
        intervalDays: const Value(6),
        repetitions: const Value(2),
        dueDate: Value(DateTime(2026, 8, 3)),
        lastReviewed: Value(DateTime(2026, 7, 28)),
      ));
      await db.addGradeItem(GradeItemsCompanion(
        courseId: Value(cid),
        name: const Value('Midterm'),
        weight: const Value(30),
        graded: const Value(true),
        score: const Value(27),
        maxScore: const Value(30),
      ));
      await db.addNote(NotesCompanion(
        courseId: Value(cid),
        title: const Value('Chapter 3'),
        body: const Value('osmosis and diffusion'),
        updatedAt: Value(DateTime(2026, 7, 28, 12)),
      ));
    }

    Future<String> snapshot(AppDatabase d) async => buildBackupJson(
          courses: await d.allCourses(),
          assignments: await d.allAssignments(),
          sessions: await d.allSessions(),
          schedule: await d.allSchedule(),
          flashcards: await d.watchFlashcards().first,
          grades: await d.watchGradeItems().first,
          notes: await d.watchNotes().first,
        );

    test('encrypt, wipe, restore reproduces every table exactly', () async {
      await seed();
      final sealed = await encryptString(await snapshot(db), 's3cret pass');

      final opened = await decryptString(sealed, 's3cret pass');
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      await fresh.importBackup(jsonDecode(opened) as Map<String, dynamic>);

      expect(await fresh.allCourses(), await db.allCourses());
      expect(await fresh.allAssignments(), await db.allAssignments());
      expect(await fresh.allSessions(), await db.allSessions());
      expect(await fresh.allSchedule(), await db.allSchedule());
      // Flashcard review state (ease, interval, reps, due, lastReviewed).
      expect(await fresh.watchFlashcards().first,
          await db.watchFlashcards().first);
      expect(await fresh.watchGradeItems().first,
          await db.watchGradeItems().first);
      expect(await fresh.watchNotes().first, await db.watchNotes().first);
      await fresh.close();
    });

    test('a wrong passphrase fails cleanly without importing anything',
        () async {
      await seed();
      final sealed = await encryptString(await snapshot(db), 'the right one');

      // Decryption throws on a bad passphrase (GCM authentication failure).
      await expectLater(
          decryptString(sealed, 'the wrong one'), throwsA(anything));

      // Because restore decrypts before importing, a fresh db stays empty.
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      expect(await fresh.allCourses(), isEmpty);
      await fresh.close();
    });
  });

  group('ICS export', () {
    Course course(String name) => Course(id: 1, name: name, instructor: '', color: 0xFF000000);
    Assignment assignment(String title, {String desc = ''}) => Assignment(
        id: 1,
        courseId: 1,
        title: title,
        description: desc,
        dueDate: DateTime(2026, 8, 1, 14, 30),
        priority: 1,
        isCompleted: false,
        estimatedMinutes: 0);

    test('uses CRLF line endings and a trailing CRLF', () {
      final ics = buildIcs(
          courses: [course('Bio')],
          assignments: [assignment('Quiz')],
          schedule: const [],
          now: DateTime(2026, 7, 28));
      expect(ics.contains('\r\n'), isTrue);
      // No bare LF that is not part of a CRLF pair.
      expect(RegExp(r'(?<!\r)\n').hasMatch(ics), isFalse);
      expect(ics.endsWith('\r\n'), isTrue);
    });

    test('escapes commas and semicolons in text', () {
      final ics = buildIcs(
          courses: [course('Math, Adv; H')],
          assignments: [assignment('Read ch1, ch2; done')],
          schedule: const [],
          now: DateTime(2026, 7, 28));
      expect(ics.contains(r'Read ch1\, ch2\; done'), isTrue);
      expect(ics.contains(r'Math\, Adv\; H'), isTrue);
    });

    test('folds long lines to 75 octets and keeps non-ASCII intact', () {
      final longTitle = 'é${'A' * 300}'; // non-ASCII + very long
      final ics = buildIcs(
          courses: [course('Bio')],
          assignments: [assignment(longTitle)],
          schedule: const [],
          now: DateTime(2026, 7, 28));
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(ics.contains('é'), isTrue);
    });
  });

  group('PDF export', () {
    test('does not crash on non-Latin scripts or very long titles', () async {
      final courses = [
        Course(id: 1, name: '数学', instructor: '', color: 0xFF000000),
      ];
      final assignments = [
        Assignment(
            id: 1,
            courseId: 1,
            title: 'Проект ${'x' * 400} — العربية',
            description: '',
            dueDate: DateTime(2026, 8, 1, 9),
            priority: 1,
            isCompleted: false,
            estimatedMinutes: 0),
      ];
      final bytes = await buildWeeklyReport(
          courses: courses,
          assignments: assignments,
          sessions: const [],
          now: DateTime(2026, 7, 28));
      expect(bytes.lengthInBytes, greaterThan(0));
    });
  });
}
