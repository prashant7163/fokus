import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Data access for `focus_sessions`. Pure persistence — legal-transition
/// enforcement lives in the session state machine (F-06), not here.
class SessionRepository {
  SessionRepository(this._db, {String Function()? idGenerator})
      : _newId = idGenerator ?? const Uuid().v4;

  final FokusDatabase _db;
  final String Function() _newId;

  /// Inserts a new `active` session and returns its id.
  ///
  /// [id] may be supplied by the caller when it must be known before the
  /// row exists (F-06 arms the native side, keyed by session id, before
  /// persisting); defaults to a fresh UUID.
  Future<String> createSession({
    required int plannedMin,
    required bool strictMode,
    String? taskAnchor,
    DateTime? startTime,
    String? id,
  }) async {
    id ??= _newId();
    await _db.into(_db.focusSessions).insert(
          FocusSessionsCompanion.insert(
            id: id,
            status: SessionStatus.active,
            startTime: startTime ?? DateTime.now(),
            plannedMin: plannedMin,
            strictMode: Value(strictMode),
            taskAnchor: Value(taskAnchor),
          ),
        );
    return id;
  }

  Future<FocusSession?> getById(String id) =>
      (_db.select(_db.focusSessions)..where((s) => s.id.equals(id)))
          .getSingleOrNull();

  /// The single non-terminal session, if any (`active` or
  /// `recoveryInProgress`).
  Future<FocusSession?> getActiveSession() =>
      (_activeQuery()).getSingleOrNull();

  Stream<FocusSession?> watchActiveSession() =>
      _activeQuery().watchSingleOrNull();

  SimpleSelectStatement<$FocusSessionsTable, FocusSession> _activeQuery() =>
      _db.select(_db.focusSessions)
        ..where(
          (s) => s.status.isInValues(
            const [SessionStatus.active, SessionStatus.recoveryInProgress],
          ),
        )
        ..limit(1);

  /// Persists a status change (e.g. active ⇄ recoveryInProgress).
  Future<void> setStatus(String id, SessionStatus status) =>
      _update(id, FocusSessionsCompanion(status: Value(status)));

  /// Adjusts the planned length of a live session — the Shrink Session
  /// recovery module (F-07 / recovery type `changeDuration`). The wall-clock
  /// anchor (`endTime = startTime + plannedMin`) is recomputed by the caller
  /// and re-armed on the native side; the session stays `active`.
  Future<void> setPlannedMin(String id, int plannedMin) =>
      _update(id, FocusSessionsCompanion(plannedMin: Value(plannedMin)));

  /// Terminal: completed (timer end, "finished task" exit, or lock-break).
  Future<void> completeSession(
    String id, {
    required CompletionReason reason,
    required int actualMin,
    DateTime? endTime,
  }) =>
      _update(
        id,
        FocusSessionsCompanion(
          status: const Value(SessionStatus.completed),
          completionReason: Value(reason),
          actualMin: Value(actualMin),
          endTime: Value(endTime ?? DateTime.now()),
        ),
      );

  /// Terminal: aborted with a structured exit reason.
  Future<void> abortSession(
    String id, {
    required ExitReason exitReason,
    required int actualMin,
    DateTime? endTime,
  }) =>
      _update(
        id,
        FocusSessionsCompanion(
          status: const Value(SessionStatus.aborted),
          exitReason: Value(exitReason),
          actualMin: Value(actualMin),
          endTime: Value(endTime ?? DateTime.now()),
        ),
      );

  /// Terminal: a required permission was revoked mid-session. Never silent.
  Future<void> failSessionPermissions(
    String id, {
    required int actualMin,
    DateTime? endTime,
  }) =>
      _update(
        id,
        FocusSessionsCompanion(
          status: const Value(SessionStatus.failedPermissions),
          actualMin: Value(actualMin),
          endTime: Value(endTime ?? DateTime.now()),
        ),
      );

  /// Records the reason of an early-exit *attempt* without ending the session
  /// (CONTRACTS §2: logged on every attempt).
  Future<void> setExitReason(String id, ExitReason reason) =>
      _update(id, FocusSessionsCompanion(exitReason: Value(reason)));

  /// Sessions with `startTime` in [from, to) — streaks/stats input.
  Future<List<FocusSession>> sessionsBetween(DateTime from, DateTime to) =>
      (_db.select(_db.focusSessions)
            ..where(
              (s) =>
                  s.startTime.isBiggerOrEqualValue(from) &
                  s.startTime.isSmallerThanValue(to),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.startTime)]))
          .get();

  /// Most recently started session — one-tap repeat of last config (F-11).
  ///
  /// NOTE: ordering semantics (most-recent-by-startTime) are load-bearing for
  /// F-11 ONLY. Attempt attribution must NOT use this (D-013 P1-D): a replayed
  /// attempt from a dead session could be misattributed to a newer session.
  /// Use [sessionsStartedBefore] with strict window containment instead.
  Future<FocusSession?> getMostRecentSession() => (_db.select(_db.focusSessions)
        ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
        ..limit(1))
      .getSingleOrNull();

  /// Sessions whose `startTime` is at or before [ts], newest first (bounded by
  /// [limit]). Attempt-attribution input (D-013 P1-D): a distraction attempt at
  /// [ts] can only belong to a session that had already started, so the caller
  /// picks the newest such session whose end-window strictly contains [ts].
  Future<List<FocusSession>> sessionsStartedBefore(
    DateTime ts, {
    int limit = 8,
  }) =>
      (_db.select(_db.focusSessions)
            ..where((s) => s.startTime.isSmallerOrEqualValue(ts))
            ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
            ..limit(limit))
          .get();

  Future<void> _update(String id, FocusSessionsCompanion companion) async {
    final rows = await (_db.update(_db.focusSessions)
          ..where((s) => s.id.equals(id)))
        .write(companion);
    if (rows == 0) {
      throw StateError('No focus_session with id $id');
    }
  }
}
