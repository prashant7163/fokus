import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'enums.dart';
import 'tables.dart';

export 'enums.dart';

part 'database.g.dart';

/// FOKUS local database. Offline-only — this file and everything under
/// lib/core/data/ must never gain a network dependency (ARCHITECTURE.md).
@DriftDatabase(
  tables: [
    FocusSessions,
    BlockedApps,
    AllowlistedApps,
    DistractionAttempts,
    RecoveryEvents,
    StreakSummary,
    Presets,
    Schedules,
    Achievements,
    FeedbackEntries,
    AiInsights,
  ],
)
class FokusDatabase extends _$FokusDatabase {
  /// Injectable executor — tests pass `NativeDatabase.memory()`.
  FokusDatabase(super.e);

  /// Opens the on-device database file (`fokus.sqlite` in app support dir).
  FokusDatabase.open() : super(driftDatabase(name: 'fokus'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
