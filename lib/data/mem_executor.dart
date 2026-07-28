import 'package:drift/drift.dart';

import 'mem_executor_native.dart'
    if (dart.library.js_interop) 'mem_executor_web.dart' as impl;

// Opens an in-memory database. The real persistence for the app is the
// encrypted vault, which loads a snapshot into this database on login and saves
// it back (encrypted) on every change.
QueryExecutor openInMemoryExecutor() => impl.openInMemoryExecutor();
