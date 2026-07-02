import 'package:drift/drift.dart';

import '../database.dart';

/// Data access for `recovery_events` — the product-hypothesis data
/// (fokus-specs §3.3: every invocation is logged; this data is sacred).
class RecoveryRepository {
  RecoveryRepository(this._db);

  final FokusDatabase _db;

  /// Logs the start of a recovery module; returns the event row id.
  Future<int> startEvent({
    required String sessionId,
    required RecoveryType type,
    DateTime? startedAt,
  }) =>
      _db.into(_db.recoveryEvents).insert(
            RecoveryEventsCompanion.insert(
              sessionId: sessionId,
              type: type,
              startedAt: startedAt ?? DateTime.now(),
            ),
          );

  /// Records the outcome ("Ready to continue?" → resumed / exited).
  Future<void> completeEvent(
    int eventId, {
    required RecoveryResult result,
    DateTime? completedAt,
  }) async {
    final rows = await (_db.update(_db.recoveryEvents)
          ..where((e) => e.id.equals(eventId)))
        .write(RecoveryEventsCompanion(
      result: Value(result),
      completedAt: Value(completedAt ?? DateTime.now()),
    ));
    if (rows == 0) {
      throw StateError('No recovery_event with id $eventId');
    }
  }

  Future<List<RecoveryEvent>> eventsForSession(String sessionId) =>
      (_db.select(_db.recoveryEvents)
            ..where((e) => e.sessionId.equals(sessionId))
            ..orderBy([(e) => OrderingTerm.asc(e.startedAt)]))
          .get();

  /// All completed events — input for resume-rate stats and recovery
  /// ordering (fokus-specs §3.6/§3.10).
  Future<List<RecoveryEvent>> completedEvents() =>
      (_db.select(_db.recoveryEvents)
            ..where((e) => e.result.isNotNull())
            ..orderBy([(e) => OrderingTerm.asc(e.startedAt)]))
          .get();
}
