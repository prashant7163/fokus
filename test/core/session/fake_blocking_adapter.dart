import 'dart:async';

import 'package:fokus/core/blocking/blocking_adapter.dart';

/// Test double for the native side. Records calls, lets tests push events
/// (including replays), and can simulate a failing startSession.
class FakeBlockingAdapter implements BlockingAdapter {
  final startedConfigs = <NativeSessionConfig>[];
  final stoppedSessionIds = <String>[];
  final blockedAppSets = <List<String>>[];

  /// When set, startSession throws — simulates a dead/erroring channel.
  Object? startError;

  Map<PermissionKind, bool> permissionMap = {
    for (final k in PermissionKind.values) k: true,
  };

  final _events = StreamController<BlockingEvent>.broadcast();

  /// Pushes an event as if the native bus emitted it. Call twice with the
  /// same payload to simulate a buffered replay.
  ///
  /// UNLIKE the real native FokusEventBus, this fake does NOT buffer events
  /// emitted before a subscriber exists — a broadcast stream drops them.
  /// Always build the controller (subscribe) BEFORE emitting, mirroring app
  /// boot order: engine attaches first, then native replays its buffer.
  void emit(BlockingEvent event) {
    assert(
      _events.hasListener,
      'emit() before the controller subscribed — the event would be silently '
      'dropped. Build the controller first (see doc comment).',
    );
    _events.add(event);
  }

  @override
  Stream<BlockingEvent> get events => _events.stream;

  @override
  Future<PermissionState> getPermissionStatus() async =>
      PermissionState(permissionMap);

  @override
  Future<void> requestPermission(PermissionKind kind) async {}

  @override
  Future<List<InstalledApp>> getInstalledApps() async => const [];

  @override
  Future<void> setBlockedApps(List<String> packageNames) async {
    blockedAppSets.add(List.of(packageNames));
  }

  @override
  Future<void> startSession(NativeSessionConfig config) async {
    final error = startError;
    if (error != null) throw error;
    startedConfigs.add(config);
  }

  @override
  Future<void> stopSession(String sessionId) async {
    stoppedSessionIds.add(sessionId);
  }

  Future<void> dispose() => _events.close();
}
