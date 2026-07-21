import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('course CRUD round-trips', () async {
    final id = await db.addCourse(CoursesCompanion(
      name: const Value('Algorithms'),
      instructor: const Value('Dr. Kaur'),
      color: const Value(0xFF4F86C6),
    ));
    var all = await db.allCourses();
    expect(all.single.name, 'Algorithms');

    await db.updateCourse(all.single.copyWith(name: 'Algorithms II'));
    all = await db.allCourses();
    expect(all.single.name, 'Algorithms II');

    await db.deleteCourse(id);
    expect(await db.allCourses(), isEmpty);
  });

  test('deleting a course cascades to its assignments and sessions', () async {
    final courseId = await db.addCourse(CoursesCompanion(
      name: const Value('Databases'),
      color: const Value(0xFF66A182),
    ));
    await db.addAssignment(AssignmentsCompanion(
      courseId: Value(courseId),
      title: const Value('ER diagram'),
      dueDate: Value(DateTime(2026, 8, 1)),
    ));
    await db.addSession(StudySessionsCompanion(
      courseId: Value(courseId),
      startTime: Value(DateTime(2026, 7, 20, 10)),
      duration: const Value(1500),
      sessionDate: Value(DateTime(2026, 7, 20)),
    ));

    await db.deleteCourse(courseId);

    expect(await db.watchAssignments().first, isEmpty);
    expect(await db.watchSessions().first, isEmpty);
  });

  test('marking an assignment complete persists', () async {
    final courseId = await db.addCourse(CoursesCompanion(
      name: const Value('Networks'),
      color: const Value(0xFFE0A458),
    ));
    final aId = await db.addAssignment(AssignmentsCompanion(
      courseId: Value(courseId),
      title: const Value('Lab 3'),
      dueDate: Value(DateTime(2026, 8, 5)),
    ));

    await db.setAssignmentComplete(aId, true);
    final list = await db.watchAssignments().first;
    expect(list.single.isCompleted, isTrue);
  });
}
