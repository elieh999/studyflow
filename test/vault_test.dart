import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/data/database.dart';
import 'package:studyflow/security/crypto.dart';

void main() {
  test('encryptWithKey / decryptWithKey round trips', () async {
    final key = await deriveVaultKey('hunter2', newSaltBase64());
    final blob = await encryptWithKey('hello world', key);
    expect(blob.contains('hello world'), isFalse); // ciphertext, not plaintext
    expect(await decryptWithKey(blob, key), 'hello world');
  });

  test('a wrong key cannot decrypt the vault', () async {
    final salt = newSaltBase64();
    final good = await deriveVaultKey('correct', salt);
    final bad = await deriveVaultKey('wrong', salt);
    final blob = await encryptWithKey('secret notes', good);
    expect(() => decryptWithKey(blob, bad), throwsA(anything));
  });

  test('full database survives an encrypted snapshot round trip', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final courseId = await db.addCourse(const CoursesCompanion(
        name: Value('Chemistry'), color: Value(0xFF4F86C6)));
    await db.addAssignment(AssignmentsCompanion(
      courseId: Value(courseId),
      title: const Value('Titration lab'),
      dueDate: Value(DateTime(2026, 9, 1)),
      estimatedMinutes: const Value(120),
    ));
    await db.addNote(NotesCompanion(
      courseId: Value(courseId),
      title: const Value('Molarity'),
      body: const Value('moles per litre'),
      updatedAt: Value(DateTime(2026, 8, 1)),
    ));

    // Snapshot -> encrypt -> decrypt -> restore into a fresh database.
    final key = await deriveVaultKey('pw', newSaltBase64());
    final blob = await encryptWithKey(jsonEncode(await db.exportAll()), key);
    final restored = await decryptWithKey(blob, key);

    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    await db2.importBackup(jsonDecode(restored) as Map<String, dynamic>);

    expect((await db2.allCourses()).single.name, 'Chemistry');
    final a = await db2.allAssignments();
    expect(a.single.title, 'Titration lab');
    expect(a.single.estimatedMinutes, 120);
    expect((await db2.watchNotes().first).single.body, 'moles per litre');

    await db.close();
    await db2.close();
  });
}
