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
  });

  final String id;
  final int endEpochMs;
  final String? taskAnchor;
  final bool strictMode;
}

/// Events reported by the native side (CONTRACTS §1). Native never decides
/// session transitions — it reports, Dart decides (CONTRACTS §2).
sealed class BlockingEvent {
  const BlockingEvent();
}

/// User opened a blocked app; the intercept fired. `ts` is the original
/// attempt time — buffered events are delivered late with their true ts.
class DistractionAttemptEvent extends BlockingEvent {
  const DistractionAttemptEvent({required this.packageName, required this.ts});

  final String packageName;
  final DateTime ts;
}

/// Intercept screen became visible for [packageName].
class InterceptShownEvent extends BlockingEvent {
  const InterceptShownEvent({required this.packageName});

  final String packageName;
}

/// User tapped "I'm stuck" on the intercept. Navigation happens separately
/// via the `fokus://recovery` deep link; this event drives the state machine.
class RecoveryRequestedEvent extends BlockingEvent {
  const RecoveryRequestedEvent();
}

/// A required permission was revoked (never silent — fokus-specs §4).
class PermissionLostEvent extends BlockingEvent {
  const PermissionLostEvent({required this.kind});

  final PermissionKind kind;
}

/// Native re-armed a session after process death or reboot; Dart must
/// re-hydrate from the DB and reconcile.
class SessionRestoredEvent extends BlockingEvent {
  const SessionRestoredEvent({required this.sessionId});

  final String sessionId;
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

  /// Broadcast stream of native events. The native bus buffers
  /// restore-critical events until this stream is listened to, then replays
  /// them — consumers must handle replay idempotently.
  Stream<BlockingEvent> get events;
}
