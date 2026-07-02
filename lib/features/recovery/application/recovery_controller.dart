import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/providers.dart';
import '../../../core/data/repositories/recovery_repository.dart';
import '../../../core/session/session_controller.dart';

/// Drives one recovery-module invocation and — critically — guarantees a
/// `recovery_events` row is written for every invocation and closed with a
/// result (fokus-specs §3.3: this data is the product hypothesis; NO code path
/// may skip it, including back-button/abandon).
///
/// Lifecycle:
///  1. [begin] — on module entry: moves the session into `recoveryInProgress`
///     (if not already) and inserts a `RecoveryEvent(type, startedAt)` row.
///  2. exactly one of:
///     - [resume] — user tapped "Resume focus": event result = `resumed`,
///       session returns to `active`.
///     - [end] — user tapped "End session": event result = `exited`; the
///       session itself is NOT touched here — the exit flow (F-08) decides
///       its fate (reason sheet, or confirm-abort when the recovery was
///       entered from the exit flow).
///     - [abandon] — back button / dismiss without choosing: event result =
///       `exited` (abandon == exited, per the brief), session left as-is.
///
/// [resume]/[end]/[abandon] are idempotent: once the event is closed, repeat
/// calls are no-ops, so a double-tap or a dispose-after-resume cannot
/// double-write.
class RecoveryController {
  RecoveryController(this._recovery, this._session, this._readSessionState);

  final RecoveryRepository _recovery;
  final SessionController _session;

  /// Reads the *current* session snapshot (not a build-time capture) so
  /// [begin] sees the live status/id.
  final SessionState Function() _readSessionState;

  int? _eventId;
  bool _closed = false;

  /// True once a module has been started and not yet resolved.
  bool get isActive => _eventId != null && !_closed;

  /// Enters [type]: ensures the session is in recovery and logs the start row.
  /// Idempotent — calling twice (e.g. a rebuild) does not double-insert.
  Future<void> begin(RecoveryType type) async {
    if (_eventId != null) return;
    final snapshot = _readSessionState();
    final sessionId = snapshot.sessionId;
    if (sessionId == null) return; // no session → nothing to log against.

    // The intercept may already have driven the session into recovery via the
    // native `recoveryRequested` event; only transition if still active.
    if (snapshot.status == SessionStatus.active) {
      await _session.enterRecovery();
    }
    _eventId = await _recovery.startEvent(sessionId: sessionId, type: type);
  }

  /// "Resume focus" → result `resumed`, back to the active session.
  Future<void> resume() async {
    if (!await _close(RecoveryResult.resumed)) return;
    if (_readSessionState().status == SessionStatus.recoveryInProgress) {
      await _session.resumeRecovery();
    }
  }

  /// "End session" → result `exited`. The session stays in
  /// `recoveryInProgress`; the exit flow (F-08) owns what happens next —
  /// it aborts, resumes, or grants a pass, each composing legal transitions.
  Future<void> end() async {
    await _close(RecoveryResult.exited);
  }

  /// Back-button / dismiss without choosing → result `exited` (abandon ==
  /// exited). The session is left in `recoveryInProgress`; the event MUST still
  /// be closed so the hypothesis data is complete.
  Future<void> abandon() async {
    await _close(RecoveryResult.exited);
  }

  /// Writes the terminal result exactly once. Returns whether this call was
  /// the one that closed it (so the caller can run its follow-up transition).
  Future<bool> _close(RecoveryResult result) async {
    if (_closed) return false;
    final id = _eventId;
    if (id == null) {
      _closed = true; // never began (no session) — later calls are no-ops.
      return false;
    }
    _closed = true;
    await _recovery.completeEvent(id, result: result);
    return true;
  }
}

/// A fresh controller per recovery-flow entry. `autoDispose` so each visit to
/// `/recovery` gets its own event lifecycle; kept alive while the flow is on
/// screen (the screen holds the ref).
final recoveryControllerProvider = Provider.autoDispose<RecoveryController>(
  (ref) => RecoveryController(
    ref.watch(recoveryRepositoryProvider),
    ref.watch(sessionControllerProvider.notifier),
    () => ref.read(sessionControllerProvider),
  ),
);
