import 'package:drift/drift.dart';

import '../database.dart';

/// Data access for `distraction_attempts`.
class DistractionRepository {
  DistractionRepository(this._db);

  final FokusDatabase _db;

  /// Logs one intercept; returns the attempt row id.
  Future<int> logAttempt({
    required String sessionId,
    required String packageName,
    DateTime? ts,
    bool recoveryInvoked = false,
  }) =>
      _db.into(_db.distractionAttempts).insert(
            DistractionAttemptsCompanion.insert(
              sessionId: sessionId,
              packageName: packageName,
              ts: ts ?? DateTime.now(),
              recoveryInvoked: Value(recoveryInvoked),
            ),
          );

  /// Marks that the user entered recovery from this intercept.
  Future<void> markRecoveryInvoked(int attemptId) =>
      (_db.update(_db.distractionAttempts)
            ..where((a) => a.id.equals(attemptId)))
          .write(const DistractionAttemptsCompanion(
        recoveryInvoked: Value(true),
      ));

  Future<List<DistractionAttempt>> attemptsForSession(String sessionId) =>
      (_db.select(_db.distractionAttempts)
            ..where((a) => a.sessionId.equals(sessionId))
            ..orderBy([(a) => OrderingTerm.asc(a.ts)]))
          .get();

  Future<int> countForSession(String sessionId) async {
    final count = _db.distractionAttempts.id.count();
    final query = _db.selectOnly(_db.distractionAttempts)
      ..addColumns([count])
      ..where(_db.distractionAttempts.sessionId.equals(sessionId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Live distraction count for the active-session screen.
  Stream<int> watchCountForSession(String sessionId) {
    final count = _db.distractionAttempts.id.count();
    final query = _db.selectOnly(_db.distractionAttempts)
      ..addColumns([count])
      ..where(_db.distractionAttempts.sessionId.equals(sessionId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Attempts since [since] — feeds the proactive-recovery rule
  /// (fokus-specs §3.2: ≥ 3 attempts in 5 min).
  Future<List<DistractionAttempt>> attemptsSince(
    String sessionId,
    DateTime since,
  ) =>
      (_db.select(_db.distractionAttempts)
            ..where(
              (a) =>
                  a.sessionId.equals(sessionId) &
                  a.ts.isBiggerOrEqualValue(since),
            )
            ..orderBy([(a) => OrderingTerm.asc(a.ts)]))
          .get();
}
