import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
// sqlite3 comes in transitively via drift; used here only for the WASM loader.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/wasm.dart';

// Web in-memory executor. Nothing is written to IndexedDB/OPFS, so no plaintext
// database is left on disk; persistence is handled by the encrypted vault.
QueryExecutor openInMemoryExecutor() => LazyDatabase(() async {
      final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
      return WasmDatabase.inMemory(sqlite3);
    });
