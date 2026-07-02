/// Pure session state machine — CONTRACTS §2, verbatim:
///
/// ```
/// idle → pendingStart → active ⇄ recoveryInProgress
/// active → completed          (timer end OR exit reason "finished task")
/// active → aborted            (emergency | unlock in future scope | lock-break in future scope)
/// active → failedPermissions  (permission revoked mid-session)
/// ```
///
/// This file owns legality and nothing else: no IO, no timers, no
/// persistence. The native side never decides transitions — it reports
/// events, Dart decides here, and the result is pushed back down
/// (session_controller.dart does the pushing).
///
/// Note the contract's shape: terminal transitions leave from `active` only.
/// A terminal outcome reached while in `recoveryInProgress` (e.g. the timer
/// expiring mid-breathe, or "End session" on the recovery result screen) is
/// composed by the controller as resumeRecovery → terminal trigger — two
/// legal steps, not a new edge.
library;

import '../data/enums.dart';

/// What can happen to a session. Each trigger is legal from exactly the
/// states listed in [SessionMachine.transitionTable].
enum SessionTrigger {
  /// User asked to start → native + DB work begins.
  startRequested,

  /// Native acked startSession and the DB row exists.
  startSucceeded,

  /// Recovery entered ("I'm stuck", exit reasons stuck/tired, proactive).
  enterRecovery,

  /// Recovery result `resumed` — back to focus.
  resumeRecovery,

  /// Wall clock reached endEpochMs (possibly detected retroactively).
  timerCompleted,

  /// Exit reason `finishedTask` — counts as completed (CONTRACTS §2).
  finishTask,

  /// Early exit: emergency now; unlock / lock-break in future scope.
  abort,

  /// A required permission was revoked mid-session.
  permissionLost,
}

/// Thrown when a trigger is applied in a state where it is not legal.
/// Reaching this in production is a programming error — callers check
/// [SessionMachine.canApply] or only fire triggers their state allows.
class IllegalSessionTransition implements Exception {
  const IllegalSessionTransition(this.from, this.trigger);

  final SessionStatus from;
  final SessionTrigger trigger;

  @override
  String toString() =>
      'IllegalSessionTransition: $trigger is not legal from $from';
}

/// The machine itself — a transition table plus two pure functions.
abstract final class SessionMachine {
  /// trigger → states it may fire from. Anything absent is illegal.
  /// This is the entire CONTRACTS §2 graph; edit only with a contract change.
  static const Map<SessionTrigger, Set<SessionStatus>> transitionTable = {
    SessionTrigger.startRequested: {SessionStatus.idle},
    SessionTrigger.startSucceeded: {SessionStatus.pendingStart},
    SessionTrigger.enterRecovery: {SessionStatus.active},
    SessionTrigger.resumeRecovery: {SessionStatus.recoveryInProgress},
    SessionTrigger.timerCompleted: {SessionStatus.active},
    SessionTrigger.finishTask: {SessionStatus.active},
    SessionTrigger.abort: {SessionStatus.active},
    SessionTrigger.permissionLost: {SessionStatus.active},
  };

  /// State reached when [trigger] fires (given it is legal).
  static const Map<SessionTrigger, SessionStatus> _target = {
    SessionTrigger.startRequested: SessionStatus.pendingStart,
    SessionTrigger.startSucceeded: SessionStatus.active,
    SessionTrigger.enterRecovery: SessionStatus.recoveryInProgress,
    SessionTrigger.resumeRecovery: SessionStatus.active,
    SessionTrigger.timerCompleted: SessionStatus.completed,
    SessionTrigger.finishTask: SessionStatus.completed,
    SessionTrigger.abort: SessionStatus.aborted,
    SessionTrigger.permissionLost: SessionStatus.failedPermissions,
  };

  static bool canApply(SessionStatus from, SessionTrigger trigger) =>
      transitionTable[trigger]!.contains(from);

  /// Returns the next state, or throws [IllegalSessionTransition].
  static SessionStatus apply(SessionStatus from, SessionTrigger trigger) {
    if (!canApply(from, trigger)) {
      throw IllegalSessionTransition(from, trigger);
    }
    return _target[trigger]!;
  }

  /// Terminal states — no trigger leaves them (a new session starts from a
  /// fresh `idle`, it never mutates a finished one).
  static const Set<SessionStatus> terminal = {
    SessionStatus.completed,
    SessionStatus.aborted,
    SessionStatus.failedPermissions,
  };

  static bool isTerminal(SessionStatus s) => terminal.contains(s);
}
