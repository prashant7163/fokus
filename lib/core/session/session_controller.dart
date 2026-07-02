import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../blocking/blocking_adapter.dart';
import '../blocking/providers.dart';
import '../data/enums.dart';
import '../data/providers.dart';
import '../data/repositories/distraction_repository.dart';
import '../data/repositories/session_repository.dart';
import 'session_machine.dart';

/// Wall clock. Tests override with a fake to drive time deterministically —
/// remaining time is always *derived* from this clock and the session's
/// endEpochMs anchor, never tick-accumulated (fokus-specs §3.1).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Periodic tick source for the active-session countdown. Tests override
/// with a manual stream (or an empty one) and call
/// [SessionController.syncWithClock] directly.
final tickerFactoryProvider = Provider<Stream<void> Function(Duration)>(
  (ref) => (period) => Stream<void>.periodic(period),
);

/// Immutable snapshot of the session engine, exposed to the UI.
class SessionState {
  const SessionState({
    required this.status,
    this.sessionId,
    this.startTime,
    this.endTime,
    this.plannedMin,
    this.taskAnchor,
    this.strictMode = false,
    this.remaining = Duration.zero,
    this.completionReason,
    this.exitReason,
    this.lostPermission,
  });

  const SessionState.idle() : this(status: SessionStatus.idle);

  final SessionStatus status;
  final String? sessionId;
  final DateTime? startTime;

  /// The wall-clock anchor: startTime + plannedMin. Remaining time is
  /// endTime − now, recomputed on every tick/resume.
  final DateTime? endTime;
  final int? plannedMin;
  final String? taskAnchor;
  final bool strictMode;
  final Duration remaining;
  final CompletionReason? completionReason;
  final ExitReason? exitReason;

  /// Minimal user-visible notice for a mid-session permission loss
  /// (requirement: never silent). F-12 owns the full permissions-health UI.
  final PermissionKind? lostPermission;

  bool get isRunning =>
      status == SessionStatus.active ||
      status == SessionStatus.recoveryInProgress;

  SessionState copyWith({
    SessionStatus? status,
    Duration? remaining,
    CompletionReason? completionReason,
    ExitReason? exitReason,
    PermissionKind? lostPermission,
    bool clearNotice = false,
  }) =>
      SessionState(
        status: status ?? this.status,
        sessionId: sessionId,
        startTime: startTime,
        endTime: endTime,
        plannedMin: plannedMin,
        taskAnchor: taskAnchor,
        strictMode: strictMode,
        remaining: remaining ?? this.remaining,
        completionReason: completionReason ?? this.completionReason,
        exitReason: exitReason ?? this.exitReason,
        lostPermission:
            clearNotice ? null : (lostPermission ?? this.lostPermission),
      );
}

/// Owns the active session lifecycle. All CONTRACTS §2 transitions are
/// decided here via [SessionMachine]; the native side only reports events.
/// Every transition persists through the F-02 session repository;
/// distractionAttempt events write DistractionAttempt rows.
///
/// CONTRACT GAP (noted, not invented): CONTRACTS §5 lists analytics events
/// (session_started, …) but §3 defines no table/sink to record them. Until
/// the contract defines one, no analytics rows are written — escalated to
/// the main session, see DISCUSSIONS 2026-07-02 F-06 entry.
class SessionController extends Notifier<SessionState>
    with WidgetsBindingObserver {
  static const _tickPeriod = Duration(seconds: 1);

  /// Grace window when attributing replayed distraction attempts to a
  /// finished session (clock skew between native ts and Dart-side endTime).
  static const _attributionGrace = Duration(minutes: 1);

  final _uuid = const Uuid();

  late BlockingAdapter _adapter;
  late SessionRepository _sessions;
  late DistractionRepository _distractions;
  late DateTime Function() _now;

  StreamSubscription<void>? _ticker;
  StreamSubscription<BlockingEvent>? _events;

  /// Replay-idempotency guard: `pkg|tsEpochMs` of attempts already written.
  /// Native buffers and replays events on (re)attach; the original ts
  /// travels with each event, so this key is stable across replays.
  final Set<String> _seenAttempts = <String>{};

  /// Serializes async event handling so a replay burst can't interleave.
  Future<void> _serial = Future.value();

  @override
  SessionState build() {
    _adapter = ref.watch(blockingAdapterProvider);
    _sessions = ref.watch(sessionRepositoryProvider);
    _distractions = ref.watch(distractionRepositoryProvider);
    _now = ref.watch(clockProvider);

    // Listening triggers the native event-bus replay of buffered events
    // (sessionRestored, permissionLost, distractionAttempt, …).
    _events = _adapter.events.listen(_enqueue);
    WidgetsBinding.instance.addObserver(this);

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _events?.cancel();
      _stopTicker();
    });

    // Cold-start hydration: an active session may exist in the DB even if
    // no sessionRestored event arrives (e.g. plain app relaunch).
    _enqueueWork(() => _hydrate(null));

    return const SessionState.idle();
  }

  // ------------------------------------------------------------- public API

  /// idle → pendingStart → active. Native is armed first; the DB row is
  /// written once native acks, then the machine lands on `active`.
  Future<void> start({
    required int plannedMin,
    String? taskAnchor,
    bool strictMode = false,
  }) async {
    // Throws unless idle; holding pendingStart also blocks a concurrent
    // second start() while native is being armed.
    state = SessionState(status: _apply(SessionTrigger.startRequested));

    final id = _uuid.v4();
    final startTime = _now();
    final endTime = startTime.add(Duration(minutes: plannedMin));

    try {
      await _adapter.startSession(
        NativeSessionConfig(
          id: id,
          endEpochMs: endTime.millisecondsSinceEpoch,
          taskAnchor: taskAnchor,
          strictMode: strictMode,
        ),
      );
      await _sessions.createSession(
        id: id,
        plannedMin: plannedMin,
        strictMode: strictMode,
        taskAnchor: taskAnchor,
        startTime: startTime,
      );
    } catch (_) {
      // Start never happened: native failed, or DB failed after native
      // armed (then disarm). Machine returns to a fresh idle — pendingStart
      // is transient and never persisted (see enums.dart).
      await _silently(() => _adapter.stopSession(id));
      state = const SessionState.idle();
      rethrow;
    }

    state = SessionState(
      status: SessionMachine.apply(
        SessionStatus.pendingStart,
        SessionTrigger.startSucceeded,
      ),
      sessionId: id,
      startTime: startTime,
      endTime: endTime,
      plannedMin: plannedMin,
      taskAnchor: taskAnchor,
      strictMode: strictMode,
      remaining: Duration(minutes: plannedMin),
    );
    _startTicker();
  }

  /// active → recoveryInProgress (persisted). Timer keeps running — there is
  /// no paused state (D-011).
  Future<void> enterRecovery() async {
    final next = _apply(SessionTrigger.enterRecovery);
    await _sessions.setStatus(state.sessionId!, next);
    state = state.copyWith(status: next);
  }

  /// recoveryInProgress → active (recovery result `resumed`).
  Future<void> resumeRecovery() async {
    final next = _apply(SessionTrigger.resumeRecovery);
    await _sessions.setStatus(state.sessionId!, next);
    state = state.copyWith(status: next);
  }

  /// Exit reason `finishedTask` → completed (CONTRACTS §2). Legal from
  /// recovery too (composed as resume → finish).
  Future<void> finishTask() async {
    await _resumeIfInRecovery();
    final next = _apply(SessionTrigger.finishTask);
    await _terminate(
      next,
      persist: (id) => _sessions.completeSession(
        id,
        reason: CompletionReason.finishedTask,
        actualMin: _elapsedMin(),
        endTime: _now(),
      ),
      completionReason: CompletionReason.finishedTask,
    );
  }

  /// Early exit → aborted. Emergency carries no penalty and no lecture
  /// (fokus-specs §2/§3.4) — it is a plain abort with exitReason=emergency.
  /// Legal from recovery too (recovery result `exited`, composed).
  Future<void> abort({required ExitReason exitReason}) async {
    await _resumeIfInRecovery();
    final next = _apply(SessionTrigger.abort);
    await _terminate(
      next,
      persist: (id) => _sessions.abortSession(
        id,
        exitReason: exitReason,
        actualMin: _elapsedMin(),
        endTime: _now(),
      ),
      exitReason: exitReason,
    );
  }

  /// Emergency exit: aborted, exitReason=emergency, no penalty, no lecture.
  Future<void> emergencyExit() => abort(exitReason: ExitReason.emergency);

  /// Records the reason of an early-exit *attempt* without ending the
  /// session (CONTRACTS §2: logged on every attempt) — F-08's exit flow
  /// calls this when the user picks a reason but stays.
  Future<void> recordExitReasonAttempt(ExitReason reason) async {
    final id = state.sessionId;
    if (id == null) return;
    await _sessions.setExitReason(id, reason);
  }

  /// Clears the permission-lost notice after the UI surfaced it.
  void clearNotice() => state = state.copyWith(clearNotice: true);

  /// Re-derives remaining time from the wall clock; fires the retroactive
  /// or on-time completion when endEpochMs has passed. Called on every
  /// tick, on app resume, and after hydration.
  Future<void> syncWithClock() async {
    if (!state.isRunning) return;
    final end = state.endTime!;
    final now = _now();
    if (now.isBefore(end)) {
      state = state.copyWith(remaining: end.difference(now));
      return;
    }
    // Timer end. If we were mid-recovery, compose resume → complete
    // (terminal edges leave from `active` only — CONTRACTS §2).
    await _resumeIfInRecovery();
    final next = _apply(SessionTrigger.timerCompleted);
    await _terminate(
      next,
      persist: (id) => _sessions.completeSession(
        id,
        reason: CompletionReason.timerEnd,
        actualMin: state.plannedMin!,
        endTime: end,
      ),
      completionReason: CompletionReason.timerEnd,
    );
  }

  // ------------------------------------------------------- app lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enqueueWork(syncWithClock);
    }
  }

  // ------------------------------------------------------- native events

  void _enqueue(BlockingEvent event) => _enqueueWork(() => _handle(event));

  void _enqueueWork(Future<void> Function() work) {
    _serial = _serial.then((_) => work()).catchError((Object e, StackTrace s) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s));
    });
  }

  /// Replayed/buffered events must be handled idempotently: an event that
  /// does not apply to the current state is dropped, never an error.
  Future<void> _handle(BlockingEvent event) async {
    switch (event) {
      case DistractionAttemptEvent(:final packageName, :final ts):
        await _logAttempt(packageName, ts);

      case RecoveryRequestedEvent():
        // Idempotent: already in recovery (replay) or session already
        // over → ignore.
        if (state.status == SessionStatus.active) {
          await enterRecovery();
        }

      case PermissionLostEvent(:final kind):
        await _onPermissionLost(kind);

      case SessionRestoredEvent(:final sessionId):
        await _hydrate(sessionId);

      case InterceptShownEvent():
        break; // informational; nothing to decide.
    }
  }

  Future<void> _logAttempt(String packageName, DateTime ts) async {
    final key = '$packageName|${ts.millisecondsSinceEpoch}';
    if (!_seenAttempts.add(key)) return; // replay duplicate

    // Attribute to the live session, else (replay after retroactive
    // completion) to the most recent session whose window covers ts.
    var sessionId = state.isRunning ? state.sessionId : null;
    if (sessionId == null) {
      final recent = await _sessions.getMostRecentSession();
      if (recent != null) {
        final windowEnd = (recent.endTime ??
                recent.startTime.add(Duration(minutes: recent.plannedMin)))
            .add(_attributionGrace);
        final inWindow = !ts.isBefore(recent.startTime) &&
            !ts.isAfter(windowEnd);
        if (inWindow) sessionId = recent.id;
      }
    }
    if (sessionId == null) {
      _seenAttempts.remove(key);
      return; // orphan event — nothing to attach it to.
    }
    await _distractions.logAttempt(
      sessionId: sessionId,
      packageName: packageName,
      ts: ts,
    );
  }

  Future<void> _onPermissionLost(PermissionKind kind) async {
    if (!state.isRunning) {
      // No session to fail (e.g. replay after the session already ended) —
      // still surface the notice; F-12 owns the full health UI.
      state = state.copyWith(lostPermission: kind);
      return;
    }
    await _resumeIfInRecovery();
    final next = _apply(SessionTrigger.permissionLost);
    await _terminate(
      next,
      persist: (id) => _sessions.failSessionPermissions(
        id,
        actualMin: _elapsedMin(),
        endTime: _now(),
      ),
    );
    state = state.copyWith(lostPermission: kind);
  }

  /// Re-hydrates from the DB (sessionRestored, or cold start when [id] is
  /// null) and reconciles against the wall clock: if endEpochMs passed
  /// while the app was dead, the session completes retroactively.
  Future<void> _hydrate(String? id) async {
    // Already tracking this live session (replay) → just reconcile.
    if (id != null && id == state.sessionId && state.isRunning) {
      return syncWithClock();
    }
    // Never clobber a live or starting session.
    if (state.isRunning || state.status == SessionStatus.pendingStart) return;

    final row = id != null
        ? await _sessions.getById(id)
        : await _sessions.getActiveSession();
    if (row == null) return;

    if (row.status != SessionStatus.active &&
        row.status != SessionStatus.recoveryInProgress) {
      // DB already terminal but native restored it → disarm native.
      await _silently(() => _adapter.stopSession(row.id));
      return;
    }

    final endTime = row.startTime.add(Duration(minutes: row.plannedMin));
    final hydrated = SessionState(
      status: row.status,
      sessionId: row.id,
      startTime: row.startTime,
      endTime: endTime,
      plannedMin: row.plannedMin,
      taskAnchor: row.taskAnchor,
      strictMode: row.strictMode,
      remaining: endTime.difference(_now()),
    );
    state = hydrated;

    if (!_now().isBefore(endTime)) {
      await syncWithClock(); // retroactive completion, persisted.
    } else {
      _startTicker();
    }
  }

  // ------------------------------------------------------------- internals

  /// Applies [trigger] to the current status via the pure machine.
  SessionStatus _apply(SessionTrigger trigger) =>
      SessionMachine.apply(state.status, trigger);

  Future<void> _resumeIfInRecovery() async {
    if (state.status == SessionStatus.recoveryInProgress) {
      await resumeRecovery();
    }
  }

  Future<void> _terminate(
    SessionStatus next, {
    required Future<void> Function(String id) persist,
    CompletionReason? completionReason,
    ExitReason? exitReason,
  }) async {
    final id = state.sessionId!;
    _stopTicker();
    await persist(id);
    await _silently(() => _adapter.stopSession(id));
    state = state.copyWith(
      status: next,
      remaining: Duration.zero,
      completionReason: completionReason,
      exitReason: exitReason,
    );
  }

  int _elapsedMin() {
    final start = state.startTime;
    if (start == null) return 0;
    final min = _now().difference(start).inMinutes;
    return min < 0 ? 0 : min;
  }

  void _startTicker() {
    _stopTicker();
    _ticker = ref
        .read(tickerFactoryProvider)(_tickPeriod)
        .listen((_) => _enqueueWork(syncWithClock));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Best-effort native call — a dead channel must not mask the real
  /// transition (state + DB already hold the truth).
  Future<void> _silently(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {/* channel unavailable; native re-syncs via restore */}
  }
}

/// The app-wide session engine.
final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
