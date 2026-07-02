import 'package:drift/native.dart';
import 'package:fokus/core/data/database.dart';

/// Fresh in-memory database per test.
FokusDatabase testDb() => FokusDatabase(NativeDatabase.memory());
