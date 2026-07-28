import 'package:drift/drift.dart';
import 'package:drift/native.dart';

// Native / test in-memory executor.
QueryExecutor openInMemoryExecutor() => NativeDatabase.memory();
