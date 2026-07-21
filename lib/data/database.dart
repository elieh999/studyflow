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
  // Rough time the student expects this to take, in minutes (0 = not set).
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(0))();
}

// A completed focus/study session. duration is stored in seconds.
class StudySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startTime => dateTime()();
  IntColumn get duration => integer()();
  DateTimeColumn get sessionDate => dateTime()();
  // How many times the student flagged a distraction during the session.
  IntColumn get distractions => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
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

// A spaced-repetition flashcard. The SM-2 fields drive the review schedule.
class Flashcards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  RealColumn get easiness => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
}

// A free-form study note attached to a course.
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
}

// One graded component of a course (e.g. "Midterm", weight 30%).
class GradeItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get weight => real()(); // percentage of the final grade
  RealColumn get score => real().withDefault(const Constant(0))(); // points earned
  RealColumn get maxScore => real().withDefault(const Constant(100))();
  // Whether this component has actually been graded yet.
  BoolColumn get graded => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(
  tables: [
    Courses,
    Assignments,
    StudySessions,
    ScheduleEntries,
    Flashcards,
    GradeItems,
    Notes,
  ],
)
class AppDatabase extends _$AppDatabase {
  // Each signed-in user gets their own database file/store via [dbName].
  AppDatabase(String dbName) : super(_openConnection(dbName));

  // Used by tests to inject an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(assignments, assignments.estimatedMinutes);
            await m.addColumn(studySessions, studySessions.distractions);
            await m.addColumn(studySessions, studySessions.note);
            await m.createTable(flashcards);
            await m.createTable(gradeItems);
          }
          if (from < 3) {
            await m.createTable(notes);
          }
        },
        beforeOpen: (details) async {
          // SQLite needs this per-connection for cascade deletes to work.
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

  Future<List<Assignment>> allAssignments() =>
      (select(assignments)..orderBy([(a) => OrderingTerm(expression: a.dueDate)]))
          .get();

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

  Future<List<StudySession>> allSessions() => select(studySessions).get();

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

  Future<List<ScheduleEntry>> allSchedule() => select(scheduleEntries).get();

  Future<int> addScheduleEntry(ScheduleEntriesCompanion e) =>
      into(scheduleEntries).insert(e);

  Future<int> deleteScheduleEntry(int id) =>
      (delete(scheduleEntries)..where((e) => e.id.equals(id))).go();

  // ---- Flashcards ----
  Stream<List<Flashcard>> watchFlashcards() => select(flashcards).watch();

  Future<int> addFlashcard(FlashcardsCompanion f) =>
      into(flashcards).insert(f);

  Future<bool> updateFlashcard(Flashcard f) => update(flashcards).replace(f);

  Future<int> deleteFlashcard(int id) =>
      (delete(flashcards)..where((f) => f.id.equals(id))).go();

  // ---- Grade items ----
  Stream<List<GradeItem>> watchGradeItems() => select(gradeItems).watch();

  Future<int> addGradeItem(GradeItemsCompanion g) =>
      into(gradeItems).insert(g);

  Future<bool> updateGradeItem(GradeItem g) => update(gradeItems).replace(g);

  Future<int> deleteGradeItem(int id) =>
      (delete(gradeItems)..where((g) => g.id.equals(id))).go();

  // ---- Notes ----
  Stream<List<Note>> watchNotes() => (select(notes)
        ..orderBy([
          (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc)
        ]))
      .watch();

  Future<int> addNote(NotesCompanion n) => into(notes).insert(n);

  Future<bool> updateNote(Note n) => update(notes).replace(n);

  Future<int> deleteNote(int id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

  // Wipes every table (children first so foreign keys are satisfied).
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(notes).go();
      await delete(gradeItems).go();
      await delete(flashcards).go();
      await delete(scheduleEntries).go();
      await delete(studySessions).go();
      await delete(assignments).go();
      await delete(courses).go();
    });
  }

  // ---- Backup / restore ----
  // Replaces all data with the contents of a backup produced by the app.
  Future<void> importBackup(Map<String, dynamic> data) async {
    List<Map<String, dynamic>> rows(String key) =>
        ((data[key] as List?) ?? const [])
            .cast<Map<String, dynamic>>();

    await transaction(() async {
      // Clear children first, then parents.
      await delete(notes).go();
      await delete(gradeItems).go();
      await delete(flashcards).go();
      await delete(scheduleEntries).go();
      await delete(studySessions).go();
      await delete(assignments).go();
      await delete(courses).go();

      // Insert parents first so foreign keys resolve.
      for (final m in rows('courses')) {
        await into(courses)
            .insert(Course.fromJson(m), mode: InsertMode.insertOrReplace);
      }
      for (final m in rows('assignments')) {
        await into(assignments).insert(Assignment.fromJson(m),
            mode: InsertMode.insertOrReplace);
      }
      for (final m in rows('sessions')) {
        await into(studySessions).insert(StudySession.fromJson(m),
            mode: InsertMode.insertOrReplace);
      }
      for (final m in rows('schedule')) {
        await into(scheduleEntries).insert(ScheduleEntry.fromJson(m),
            mode: InsertMode.insertOrReplace);
      }
      for (final m in rows('flashcards')) {
        await into(flashcards).insert(Flashcard.fromJson(m),
            mode: InsertMode.insertOrReplace);
      }
      for (final m in rows('grades')) {
        await into(gradeItems)
            .insert(GradeItem.fromJson(m), mode: InsertMode.insertOrReplace);
      }
      for (final m in rows('notes')) {
        await into(notes)
            .insert(Note.fromJson(m), mode: InsertMode.insertOrReplace);
      }
    });
  }
}

// drift_flutter picks the right backend automatically:
//  - desktop/mobile: a native SQLite file under the app documents folder
//  - web: a WASM SQLite build persisted in the browser (IndexedDB/OPFS)
QueryExecutor _openConnection(String name) {
  return driftDatabase(
    name: name,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
