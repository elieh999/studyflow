import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/data/database.dart';
import 'package:studyflow/export/exporters.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> seedCourse() => db.addCourse(const CoursesCompanion(
        name: Value('Physics'),
        color: Value(0xFF4F86C6),
      ));

  test('flashcards persist and cascade on course delete', () async {
    final courseId = await seedCourse();
    await db.addFlashcard(FlashcardsCompanion(
      courseId: Value(courseId),
      question: const Value('Unit of force?'),
      answer: const Value('Newton'),
      dueDate: Value(DateTime(2026, 7, 21)),
    ));
    expect(await db.watchFlashcards().first, hasLength(1));
    await db.deleteCourse(courseId);
    expect(await db.watchFlashcards().first, isEmpty);
  });

  test('grade items persist and update', () async {
    final courseId = await seedCourse();
    final id = await db.addGradeItem(GradeItemsCompanion(
      courseId: Value(courseId),
      name: const Value('Midterm'),
      weight: const Value(30),
    ));
    var items = await db.watchGradeItems().first;
    expect(items.single.weight, 30);
    await db.updateGradeItem(
        items.single.copyWith(graded: true, score: 27, maxScore: 30));
    items = await db.watchGradeItems().first;
    expect(items.single.graded, isTrue);
    expect(items.single.score, 27);
    await db.deleteGradeItem(id);
    expect(await db.watchGradeItems().first, isEmpty);
  });

  test('backup can be exported and restored into a fresh database', () async {
    final courseId = await seedCourse();
    await db.addAssignment(AssignmentsCompanion(
      courseId: Value(courseId),
      title: const Value('Lab report'),
      dueDate: Value(DateTime(2026, 8, 1)),
      estimatedMinutes: const Value(90),
    ));
    await db.addFlashcard(FlashcardsCompanion(
      courseId: Value(courseId),
      question: const Value('q'),
      answer: const Value('a'),
      dueDate: Value(DateTime(2026, 7, 21)),
    ));

    final json = buildBackupJson(
      courses: await db.allCourses(),
      assignments: await db.allAssignments(),
      sessions: await db.allSessions(),
      schedule: await db.allSchedule(),
      flashcards: await db.watchFlashcards().first,
      grades: await db.watchGradeItems().first,
    );

    // Restore into a brand-new database.
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    await fresh.importBackup(jsonDecode(json) as Map<String, dynamic>);

    expect((await fresh.allCourses()).single.name, 'Physics');
    final a = await fresh.allAssignments();
    expect(a.single.title, 'Lab report');
    expect(a.single.estimatedMinutes, 90);
    expect(await fresh.watchFlashcards().first, hasLength(1));
    await fresh.close();
  });

  test('ics export contains an event for each assignment', () async {
    final courseId = await seedCourse();
    await db.addAssignment(AssignmentsCompanion(
      courseId: Value(courseId),
      title: const Value('Quiz'),
      dueDate: Value(DateTime(2026, 8, 3, 14, 0)),
    ));
    final ics = buildIcs(
      courses: await db.allCourses(),
      assignments: await db.allAssignments(),
      schedule: await db.allSchedule(),
      now: DateTime(2026, 7, 21),
    );
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('[Physics] Quiz'));
    expect(ics, contains('END:VCALENDAR'));
  });
}
