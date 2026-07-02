import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../blocking/blocking_adapter.dart';
import '../blocking/providers.dart';
import '../constants.dart';
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
    this.passPackage,
    this.passEndTime,
    this.hydrated = false,
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

  /// Live single-app pass (F-08 "need one app", non-strict): [passPackage] is
  /// usable until [passEndTime] while the session timer keeps running. UI-side
  /// mirror of the native pass — drives the countdown chip; cleared on expiry
  /// by the tick, on shrink, and on any terminal transition.
  final String? passPackage;
  final DateTime? passEndTime;

  /// False only during the cold-start window before the first DB hydration
  /// resolves. Deep-linked screens (exit sheet, recovery) must not treat the
  /// transient initial `idle` as "no session" — wait for this flag (M2
  /// finding: the intercept's emergency-exit deep link bounced home).
  final bool hydrated;

  bool get isRunning =>
      status == SessionStatus.active ||
      status == SessionStatus.recoveryInProgress;

  bool get hasActivePass => passPackage != null;

  SessionState copyWith({
    SessionStatus? status,
    Duration? remaining,
    CompletionReason? completionReason,
    ExitReason? exitReason,
    PermissionKind? lostPermission,
    String? passPackage,
    DateTime? passEndTime,
    bool clearNotice = false,
    bool clearPass = false,
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
        passPackage: clearPass ? null : (passPackage ?? this.passPackage),
        passEndTime: clearPass ? null : (passEndTime ?? this.passEndTime),
        hydrated: hydrated,
      );

  /// The same state with [hydrated] set — the first DB look-up concluded.
  SessionState asHydrated() => hydrated
      ? this
      : SessionState(
          status: status,
          sessionId: sessionId,
          startTime: startTime,
          endTime: endTime,
          plannedMin: plannedMin,
          taskAnchor: taskAnchor,
          strictMode: strictMode,
          remaining: remaining,
          completionReason: completionReason,
          exitReason: exitReason,
          lostPermission: lostPermission,
          passPackage: passPackage,
          passEndTime: passEndTime,
          hydrated: true,
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
    // A finished session's terminal state stays on screen until the next
    // start; the new session begins from a fresh idle (SessionMachine.terminal
    // — a trigger never leaves a terminal state).
    if (SessionMachine.isTerminal(state.status)) {
      state = SessionState(status: SessionStatus.idle, hydrated: true);
    }

    // Throws unless idle; holding pendingStart also blocks a concurrent
    // second start() while native is being armed.
    state = SessionState(
      status: _apply(SessionTrigger.startRequested),
      hydrated: true,
    );

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
      state = SessionState(status: SessionStatus.idle, hydrated: true);
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
      hydrated: true,
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

  /// Shrink Session recovery module (F-07, recovery type `changeDuration`):
  /// reduce the remaining time to [remainingMin] minutes and re-anchor the
  /// wall clock. Machine-legal: the session stays `active` — this is a config
  /// change, not a transition (no new CONTRACTS §2 edge). Called from recovery,
  /// so it first composes resume → active if mid-recovery.
  ///
  /// No-op if the current remaining is already ≤ [remainingMin] (the module is
  /// hidden/disabled in that case; guarded here too so it can never *extend* a
  /// session). The new `plannedMin` is elapsed + [remainingMin] so a later
  /// timer-end records an honest `actualMin`.
  Future<void> shrinkTo({int remainingMin = 10}) async {
    if (!state.isRunning) return;
    final now = _now();
    final currentRemaining = state.endTime!.difference(now);
    if (currentRemaining <= Duration(minutes: remainingMin)) {
      // Never extends — but `remaining` is wall-clock-derived, so refresh it
      // to the value just computed instead of leaving the last tick's.
      state = state.copyWith(remaining: currentRemaining);
      return;
    }

    await _resumeIfInRecovery();

    final id = state.sessionId!;
    final newEnd = now.add(Duration(minutes: remainingMin));
    final elapsed = _elapsedMin();
    final newPlanned = elapsed + remainingMin;

    // Re-arm native with the new anchor (same id → single-session cache is
    // overwritten in place). Best-effort like other native calls.
    await _silently(
      () => _adapter.startSession(
        NativeSessionConfig(
          id: id,
          endEpochMs: newEnd.millisecondsSinceEpoch,
          taskAnchor: state.taskAnchor,
          strictMode: state.strictMode,
        ),
      ),
    );
    await _sessions.setPlannedMin(id, newPlanned);

    state = SessionState(
      status: SessionStatus.active,
      sessionId: id,
      startTime: state.startTime,
      endTime: newEnd,
      plannedMin: newPlanned,
      taskAnchor: state.taskAnchor,
      strictMode: state.strictMode,
      remaining: newEnd.difference(now),
      hydrated: true,
    );
    _startTicker();
  }

  /// F-08 "need one app" (non-strict only): grants [packageName] a
  /// [FokusConstants.appPassMinutes]-minute pass while the session timer keeps
  /// running (fokus-specs §3.4 — this is NOT a pause, D-011). The pass never
  /// outlives the session. One pass at a time: a new grant replaces the old.
  ///
  /// Strict mode never reaches here (the exit flow shows the kind denial
  /// instead); a call anyway is a programming error.
  Future<void> grantAppPass(String packageName) async {
    if (!state.isRunning) return;
    if (state.strictMode) {
      throw StateError(
        'needApp pass is not available in strict mode (fokus-specs §3.4)',
      );
    }
    await _resumeIfInRecovery();

    final now = _now();
    var passEnd =
        now.add(const Duration(minutes: FokusConstants.appPassMinutes));
    final sessionEnd = state.endTime!;
    if (passEnd.isAfter(sessionEnd)) passEnd = sessionEnd;

    // Not best-effort: if native can't record the pass the app stays
    // intercepted, so pretending it was granted would gaslight the user.
    await _adapter.grantAppPass(packageName, passEnd.millisecondsSinceEpoch);
    state = state.copyWith(passPackage: packageName, passEndTime: passEnd);
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
      // The single-app pass expires by wall clock too (native mirrors this).
      final passOver =
          state.passEndTime != null && !now.isBefore(state.passEndTime!);
      state = state.copyWith(
        remaining: end.difference(now),
        clearPass: passOver,
      );
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
      case DistractionAttemptEvent(:final packageName, :final ts, :final seq):
        await _logAttempt(packageName, ts, seq);

      case RecoveryRequestedEvent(:final seq):
        // Idempotent: already in recovery (replay) or session already
        // over → ignore. Acked regardless: the journal entry has been
        // consumed once the state is (or already was) reconciled.
        if (state.status == SessionStatus.active) {
          await enterRecovery();
        }
        await _ack(seq);

      case PermissionLostEvent(:final kind):
        await _onPermissionLost(kind);

      case SessionRestoredEvent(:final sessionId):
        await _hydrate(sessionId);

      case StopMismatchEvent(:final requestedId, :final liveId):
        await _onStopMismatch(requestedId, liveId);

      case InterceptShownEvent():
        break; // informational; nothing to decide.
    }
  }

  /// Acks a journalled event by seq (D-013 P1-A) once it is durably written.
  /// Best-effort: a dead channel just means the entry replays next attach and
  /// the `pkg|ts` guard dedupes it.
  Future<void> _ack(int? seq) async {
    if (seq == null) return;
    await _silently(() => _adapter.ackEvents(seq));
  }

  Future<void> _logAttempt(String packageName, DateTime ts, int? seq) async {
    final key = '$packageName|${ts.millisecondsSinceEpoch}';
    if (!_seenAttempts.add(key)) {
      // Already written on a prior replay → still ack so native can drop it.
      await _ack(seq);
      return;
    }

    final sessionId = await _attributeAttempt(ts);
    if (sessionId == null) {
      // Orphan: no session's window contains ts (D-013 P1-D — never fall back
      // to "most recent regardless of window"). Log + discard. Ack anyway so
      // the journal does not replay an event we will always discard.
      _seenAttempts.remove(key);
      debugPrint(
        'fokus: distraction attempt at $ts (pkg=$packageName) matched no '
        'session window — discarded (D-013 P1-D).',
      );
      await _ack(seq);
      return;
    }
    await _distractions.logAttempt(
      sessionId: sessionId,
      packageName: packageName,
      ts: ts,
    );
    await _ack(seq);
  }

  /// Attributes an attempt at [ts] to a session by **timestamp containment
  /// only** (D-013 P1-D). The live session wins if its window contains ts;
  /// otherwise the newest already-started session whose window
  /// `[startTime, endTime|planned end + grace]` strictly contains ts. Never
  /// "most recent session regardless of window" — that misattributes a
  /// replayed attempt from a dead session to a newer one.
  Future<String?> _attributeAttempt(DateTime ts) async {
    if (state.isRunning &&
        state.sessionId != null &&
        _windowContains(state.startTime!, state.endTime!, ts)) {
      return state.sessionId;
    }
    final candidates = await _sessions.sessionsStartedBefore(ts);
    for (final row in candidates) {
      final end =
          row.endTime ?? row.startTime.add(Duration(minutes: row.plannedMin));
      if (_windowContains(row.startTime, end, ts)) return row.id;
    }
    return null;
  }

  /// True when [ts] is within `[start, end + grace]` — the grace absorbs clock
  /// skew between the native attempt ts and the Dart-side end anchor.
  bool _windowContains(DateTime start, DateTime end, DateTime ts) {
    final windowEnd = end.add(_attributionGrace);
    return !ts.isBefore(start) && !ts.isAfter(windowEnd);
  }

  /// D-013 P1-C: native dropped [liveId] because Dart asked to stop
  /// [requestedId]. If Dart is still tracking [liveId] as live, its native
  /// arming is now gone — Dart's decision wins, so abort the orphaned session
  /// (structured as a `stuck` abort; F-08 refines exit reasons). Otherwise the
  /// mismatch is already reconciled — just log it.
  Future<void> _onStopMismatch(String requestedId, String liveId) async {
    debugPrint(
      'fokus: stopSession($requestedId) mismatched live native session '
      '$liveId (D-013 P1-C) — reconciling.',
    );
    if (state.isRunning && state.sessionId == liveId) {
      await _resumeIfInRecovery();
      final next = _apply(SessionTrigger.abort);
      await _terminate(
        next,
        persist: (id) => _sessions.abortSession(
          id,
          exitReason: ExitReason.stuck,
          actualMin: _elapsedMin(),
          endTime: _now(),
        ),
        exitReason: ExitReason.stuck,
      );
    }
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
    if (row == null) {
      // The look-up concluded: there really is no session. Deep-linked
      // screens may now trust `idle` (M2 finding — see SessionState.hydrated).
      state = state.asHydrated();
      return;
    }

    if (row.status != SessionStatus.active &&
        row.status != SessionStatus.recoveryInProgress) {
      // DB already terminal but native restored it → disarm native.
      await _silently(() => _adapter.stopSession(row.id));
      state = state.asHydrated();
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
      hydrated: true,
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
      clearPass: true,
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
