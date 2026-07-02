/// Dart side of the blocking contract — CONTRACTS §1.
///
/// The abstract [BlockingAdapter] is what the session engine and UI depend
/// on; [ChannelBlockingAdapter] (channel_blocking_adapter.dart) is the real
/// implementation, tests use a fake. Payload shapes mirror
/// `BlockingChannelHandler.kt` / `FokusEventBus.kt` exactly — change those
/// files and this one together (contract change → DECISIONS entry).
library;

/// The four OS permissions the blocking core depends on (CONTRACTS §1).
enum PermissionKind { accessibility, usageStats, notifications, batteryExemption }

/// Snapshot of all permission states, as reported by the native side.
class PermissionState {
  const PermissionState(this._granted);

  final Map<PermissionKind, bool> _granted;

  bool isGranted(PermissionKind kind) => _granted[kind] ?? false;

  /// Blocking works at all ⇔ accessibility is granted; the other three are
  /// resilience/UX-quality permissions (fokus-specs §3.11).
  bool get blockingReady => isGranted(PermissionKind.accessibility);

  bool get allGranted => PermissionKind.values.every(isGranted);

  Map<PermissionKind, bool> asMap() => Map.unmodifiable(_granted);

  @override
  String toString() => 'PermissionState($_granted)';
}

/// Launchable app metadata for the blocked-app picker.
class InstalledApp {
  const InstalledApp({required this.packageName, required this.appName});

  final String packageName;
  final String appName;

  @override
  bool operator ==(Object other) =>
      other is InstalledApp &&
      other.packageName == packageName &&
      other.appName == appName;

  @override
  int get hashCode => Object.hash(packageName, appName);
}

/// Config pushed down to the native core at session start.
///
/// `endEpochMs` is the wall-clock anchor: both sides derive remaining time
/// from it — never tick-accumulated (fokus-specs §3.1).
class NativeSessionConfig {
  const NativeSessionConfig({
    required this.id,
    required this.endEpochMs,
    required this.strictMode,
    this.taskAnchor,
    this.startedEpochMs = 0,
    this.recoveryEnabled = true,
  });

  final String id;
  final int endEpochMs;
  final String? taskAnchor;
  final bool strictMode;

  /// Start anchor (F-13, D-022) — lets Dart synthesize the DB row for a
  /// session a schedule auto-started natively.
  final int startedEpochMs;

  /// Preset flag (F-13): false hides the intercept's "I'm stuck" CTA + hint.
  final bool recoveryEnabled;
}

/// One enabled schedule pushed to native via `syncSchedules` (F-13, D-022):
/// the joined preset config + ISO weekdays (1 = Mon … 7 = Sun) + "HH:mm"
/// local start time. Policy lives in Dart; native only arms WorkManager.
class ScheduleSync {
  const ScheduleSync({
    required this.id,
    required this.presetName,
    required this.packages,
    required this.durationMin,
    required this.strictMode,
    required this.recoveryEnabled,
    required this.daysOfWeek,
    required this.startLocalTime,
  });

  final int id;
  final String presetName;
  final List<String> packages;
  final int durationMin;
  final bool strictMode;
  final bool recoveryEnabled;
  final List<int> daysOfWeek;
  final String startLocalTime;

  Map<String, Object?> toMap() => {
        'id': id,
        'presetName': presetName,
        'packages': packages,
        'durationMin': durationMin,
        'strictMode': strictMode,
        'recoveryEnabled': recoveryEnabled,
        'daysOfWeek': daysOfWeek,
        'startLocalTime': startLocalTime,
      };
}

/// Events reported by the native side (CONTRACTS §1). Native never decides
/// session transitions — it reports, Dart decides (CONTRACTS §2).
sealed class BlockingEvent {
  const BlockingEvent();
}

/// User opened a blocked app; the intercept fired. `ts` is the original
/// attempt time — journalled events are delivered late with their true ts.
///
/// [seq] is the native [AttemptJournal] sequence number (D-013 P1-A). It is
/// present for journalled deliveries (the normal case) and null only for a
/// legacy/live event without a journal entry. Dart acks the highest seq it has
/// durably written so the native journal can drop it.
class DistractionAttemptEvent extends BlockingEvent {
  const DistractionAttemptEvent({
    required this.packageName,
    required this.ts,
    this.seq,
  });

  final String packageName;
  final DateTime ts;
  final int? seq;
}

/// Intercept screen became visible for [packageName].
class InterceptShownEvent extends BlockingEvent {
  const InterceptShownEvent({required this.packageName});

  final String packageName;
}

/// User tapped "I'm stuck" on the intercept. Navigation happens separately
/// via the `fokus://recovery` deep link; this event drives the state machine.
///
/// Journalled like [DistractionAttemptEvent] (D-013 P1-A): [seq] is the native
/// journal sequence number, acked once handled.
class RecoveryRequestedEvent extends BlockingEvent {
  const RecoveryRequestedEvent({this.seq});

  final int? seq;
}

/// A required permission was revoked (never silent — fokus-specs §4).
class PermissionLostEvent extends BlockingEvent {
  const PermissionLostEvent({required this.kind});

  final PermissionKind kind;
}

/// Native re-armed a session after process death or reboot — or a schedule
/// auto-started one (F-13). Dart re-hydrates from the DB and reconciles;
/// when no row exists and the config fields are present, it synthesizes the
/// row from them (D-022).
class SessionRestoredEvent extends BlockingEvent {
  const SessionRestoredEvent({
    required this.sessionId,
    this.startedEpochMs,
    this.endEpochMs,
    this.taskAnchor,
    this.strictMode,
    this.recoveryEnabled,
  });

  final String sessionId;
  final int? startedEpochMs;
  final int? endEpochMs;
  final String? taskAnchor;
  final bool? strictMode;
  final bool? recoveryEnabled;

  /// True when the payload carries enough to synthesize a missing DB row.
  bool get hasConfig =>
      startedEpochMs != null && startedEpochMs! > 0 && endEpochMs != null;
}

/// Diagnostic (D-013 P1-C): `stopSession(requestedId)` was called while native
/// held a *different* live session [liveId]. Native has already dropped its
/// session (Dart decides liveness); Dart logs the mismatch and reconciles —
/// if it is still tracking [liveId] as live, that session's native arming is
/// gone, so Dart must terminate it too. CONTRACTS §1 addendum (sanctioned by
/// D-013).
class StopMismatchEvent extends BlockingEvent {
  const StopMismatchEvent({required this.requestedId, required this.liveId});

  final String requestedId;
  final String liveId;
}

/// CONTRACTS §1 — facade over MethodChannel `fokus/blocking` and
/// EventChannel `fokus/events`.
abstract class BlockingAdapter {
  Future<PermissionState> getPermissionStatus();

  /// Opens the settings screen where [kind] can be granted.
  Future<void> requestPermission(PermissionKind kind);

  Future<List<InstalledApp>> getInstalledApps();

  Future<void> setBlockedApps(List<String> packageNames);

  Future<void> startSession(NativeSessionConfig config);

  Future<void> stopSession(String sessionId);

  /// Grants the F-08 single-app pass: [packageName] is not intercepted until
  /// [endEpochMs] (wall-clock, persisted natively — survives process death,
  /// expires without a timer). Dart is policy: duration, strict-mode gating
  /// and the one-pass-at-a-time rule are decided in the session engine; the
  /// native side only records and enforces the window. CONTRACTS §1 addendum
  /// (D-015).
  Future<void> grantAppPass(String packageName, int endEpochMs);

  /// Acks journalled events up to and including [upToSeq] (D-013 P1-A). The
  /// native [AttemptJournal] drops acked entries; delivery is at-least-once,
  /// so Dart must have durably written the attempt before acking.
  Future<void> ackEvents(int upToSeq);

  /// Launcher icons as PNG bytes keyed by package name (F-11 UI, D-019).
  /// Missing/uninstalled packages are omitted — callers fall back to a glyph.
  Future<Map<String, List<int>>> getAppIcons(List<String> packageNames);

  /// Replaces the native schedule set (F-13, D-022): native persists the
  /// list and (re)arms WorkManager for each schedule's next occurrence
  /// (reminder at T−5 min with Skip; auto-start at T unless a session is
  /// already live). Pass the ENABLED schedules only.
  Future<void> syncSchedules(List<ScheduleSync> schedules);

  /// The session the native cache currently holds, or null (F-13, D-024).
  /// Cold-start reconciliation reads this so a schedule-auto-started session
  /// is not lost when the buffered sessionRestored event never reached a
  /// live engine.
  Future<SessionRestoredEvent?> getActiveNativeSession();

  /// Broadcast stream of native events. The native bus buffers
  /// restore-critical events until this stream is listened to, then replays
  /// them — consumers must handle replay idempotently.
  Stream<BlockingEvent> get events;
}
