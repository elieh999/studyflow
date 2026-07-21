import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../security/crypto.dart';
import 'exporters.dart';
import 'web_files.dart';

// Builds a JSON snapshot of everything in the database.
Future<String> _snapshot(AppDatabase db) async => buildBackupJson(
      courses: await db.allCourses(),
      assignments: await db.allAssignments(),
      sessions: await db.allSessions(),
      schedule: await db.allSchedule(),
      flashcards: await db.watchFlashcards().first,
      grades: await db.watchGradeItems().first,
      notes: await db.watchNotes().first,
    );

// Offers a plain or AES-256-GCM encrypted backup download.
Future<void> exportBackupFlow(BuildContext context, AppDatabase db) async {
  final passCtrl = TextEditingController();
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Back up your data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Download a copy of all your data. Add a passphrase to encrypt it '
              '(AES-256) — you\'ll need the same passphrase to restore it.'),
          const SizedBox(height: 12),
          TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Passphrase (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, 'go'),
            child: const Text('Download')),
      ],
    ),
  );
  if (choice != 'go') return;

  final json = await _snapshot(db);
  final pass = passCtrl.text.trim();
  if (pass.isEmpty) {
    downloadText('studyflow_backup.json', json, 'application/json');
  } else {
    final sealed = await encryptString(json, pass);
    downloadText('studyflow_backup.enc.json', sealed, 'application/json');
  }
}

// Picks a backup file, decrypting first if it's encrypted, then restores it.
Future<void> restoreBackupFlow(BuildContext context, AppDatabase db) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = await pickTextFile();
  if (text == null) return;

  var json = text;
  if (looksEncrypted(text)) {
    if (!context.mounted) return;
    final pass = await _askPassphrase(context);
    if (pass == null) return;
    try {
      json = await decryptString(text, pass);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Wrong passphrase, or the file is corrupted.')));
      return;
    }
  }

  try {
    await db.importBackup(jsonDecode(json) as Map<String, dynamic>);
    messenger
        .showSnackBar(const SnackBar(content: Text('Data restored from backup.')));
  } catch (e) {
    messenger
        .showSnackBar(SnackBar(content: Text('Could not read that backup: $e')));
  }
}

Future<String?> _askPassphrase(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Encrypted backup'),
      content: TextField(
        controller: ctrl,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Passphrase',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => Navigator.pop(context, ctrl.text),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Restore')),
      ],
    ),
  );
}
