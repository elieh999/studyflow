import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// A course the student is taking. Everything else hangs off this.
class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get instructor => text().withDefault(const Constant(''))();
  // Stored as an ARGB int so we can rebuild a Color directly.
  IntColumn get color => integer()();
}

// A piece of work due for a course. priority: 0 = low, 1 = medium, 2 = high.
class Assignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

// A completed focus/study session. duration is stored in seconds.
class StudySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startTime => dateTime()();
  IntColumn get duration => integer()();
  DateTimeColumn get sessionDate => dateTime()();
}

// A recurring weekly class meeting for the schedule view.
// dayOfWeek: 1 = Monday ... 7 = Sunday. Times are "HH:mm" strings.
class ScheduleEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayOfWeek => integer()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get location => text().withDefault(const Constant(''))();
}

@DriftDatabase(
  tables: [Courses, Assignments, StudySessions, ScheduleEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Used by tests to inject an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          // SQLite needs this on per-connection for cascade deletes to work.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---- Courses ----
  Stream<List<Course>> watchCourses() =>
      (select(courses)..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .watch();

  Future<List<Course>> allCourses() =>
      (select(courses)..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .get();

  Future<int> addCourse(CoursesCompanion c) => into(courses).insert(c);

  Future<bool> updateCourse(Course c) => update(courses).replace(c);

  Future<int> deleteCourse(int id) =>
      (delete(courses)..where((c) => c.id.equals(id))).go();

  // ---- Assignments ----
  Stream<List<Assignment>> watchAssignments() =>
      (select(assignments)..orderBy([(a) => OrderingTerm(expression: a.dueDate)]))
          .watch();

  Future<int> addAssignment(AssignmentsCompanion a) =>
      into(assignments).insert(a);

  Future<bool> updateAssignment(Assignment a) =>
      update(assignments).replace(a);

  Future<int> deleteAssignment(int id) =>
      (delete(assignments)..where((a) => a.id.equals(id))).go();

  Future<void> setAssignmentComplete(int id, bool done) =>
      (update(assignments)..where((a) => a.id.equals(id)))
          .write(AssignmentsCompanion(isCompleted: Value(done)));

  // ---- Study sessions ----
  Stream<List<StudySession>> watchSessions() => select(studySessions).watch();

  Future<int> addSession(StudySessionsCompanion s) =>
      into(studySessions).insert(s);

  // ---- Schedule ----
  Stream<List<ScheduleEntry>> watchSchedule() =>
      (select(scheduleEntries)
            ..orderBy([
              (e) => OrderingTerm(expression: e.dayOfWeek),
              (e) => OrderingTerm(expression: e.startTime),
            ]))
          .watch();

  Future<int> addScheduleEntry(ScheduleEntriesCompanion e) =>
      into(scheduleEntries).insert(e);

  Future<int> deleteScheduleEntry(int id) =>
      (delete(scheduleEntries)..where((e) => e.id.equals(id))).go();
}

// drift_flutter picks the right backend automatically:
//  - desktop/mobile: a native SQLite file under the app documents folder
//  - web: a WASM SQLite build persisted in the browser (IndexedDB/OPFS)
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'studyflow',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
