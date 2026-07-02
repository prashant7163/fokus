import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'blocking_adapter.dart';

/// Real [BlockingAdapter] over the platform channels. Payload shapes are
/// documented in `BlockingChannelHandler.kt` and `FokusEventBus.kt` — this
/// file matches them 1:1 and adds nothing.
class ChannelBlockingAdapter implements BlockingAdapter {
  /// Channel overrides exist for channel-level tests only; production code
  /// always uses the defaults.
  ChannelBlockingAdapter({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _method = methodChannel ?? const MethodChannel('fokus/blocking'),
        _event = eventChannel ?? const EventChannel('fokus/events');

  final MethodChannel _method;
  final EventChannel _event;

  Stream<BlockingEvent>? _events;

  @override
  Future<PermissionState> getPermissionStatus() async {
    final raw = await _method.invokeMethod<Map<Object?, Object?>>(
      'getPermissionStatus',
    );
    final granted = <PermissionKind, bool>{
      for (final kind in PermissionKind.values)
        kind: raw?[kind.name] == true,
    };
    return PermissionState(granted);
  }

  @override
  Future<void> requestPermission(PermissionKind kind) =>
      _method.invokeMethod<void>('requestPermission', {'kind': kind.name});

  @override
  Future<List<InstalledApp>> getInstalledApps() async {
    final raw =
        await _method.invokeMethod<List<Object?>>('getInstalledApps') ??
            const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (m) => InstalledApp(
            packageName: m['packageName']! as String,
            appName: m['appName']! as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> setBlockedApps(List<String> packageNames) =>
      _method.invokeMethod<void>('setBlockedApps', {
        'packageNames': packageNames,
      });

  @override
  Future<void> startSession(NativeSessionConfig config) =>
      _method.invokeMethod<void>('startSession', {
        'id': config.id,
        'endEpochMs': config.endEpochMs,
        'taskAnchor': config.taskAnchor,
        'strictMode': config.strictMode,
      });

  @override
  Future<void> stopSession(String sessionId) =>
      _method.invokeMethod<void>('stopSession', {'sessionId': sessionId});

  @override
  Stream<BlockingEvent> get events => _events ??= _event
      .receiveBroadcastStream()
      .map(_parse)
      .where((event) => event != null)
      .cast<BlockingEvent>()
      .asBroadcastStream();

  /// Maps a raw `fokus/events` payload to a [BlockingEvent]. Unknown types
  /// return null (skipped) so an older Dart build survives a newer native
  /// side — the mismatch is logged, never fatal.
  BlockingEvent? _parse(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    switch (type) {
      case 'distractionAttempt':
        return DistractionAttemptEvent(
          packageName: raw['pkg'] as String,
          ts: DateTime.fromMillisecondsSinceEpoch((raw['ts'] as num).toInt()),
        );
      case 'interceptShown':
        return InterceptShownEvent(packageName: raw['pkg'] as String);
      case 'recoveryRequested':
        return const RecoveryRequestedEvent();
      case 'permissionLost':
        for (final kind in PermissionKind.values) {
          if (kind.name == raw['kind']) return PermissionLostEvent(kind: kind);
        }
        debugPrint('fokus/events: unknown permission kind "${raw['kind']}"');
        return null;
      case 'sessionRestored':
        return SessionRestoredEvent(sessionId: raw['sessionId'] as String);
      default:
        debugPrint('fokus/events: unknown event type "$type" skipped');
        return null;
    }
  }
}
