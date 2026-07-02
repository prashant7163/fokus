import 'dart:async';

import 'package:fokus/core/blocking/blocking_adapter.dart';

/// Test double for the native side. Records calls, lets tests push events
/// (including replays), and can simulate a failing startSession.
class FakeBlockingAdapter implements BlockingAdapter {
  final startedConfigs = <NativeSessionConfig>[];
  final stoppedSessionIds = <String>[];
  final blockedAppSets = <List<String>>[];

  /// Every `ackEvents(upToSeq)` call, in order (D-013 P1-A).
  final ackedSeqs = <int>[];

  /// Every `grantAppPass` call, in order (F-08 single-app pass).
  final grantedPasses = <({String packageName, int endEpochMs})>[];

  /// When set, startSession throws — simulates a dead/erroring channel.
  Object? startError;

  /// When set, grantAppPass throws — the pass grant deliberately propagates
  /// (a failed grant must not be celebrated as success).
  Object? grantPassError;

  Map<PermissionKind, bool> permissionMap = {
    for (final k in PermissionKind.values) k: true,
  };

  /// Every `requestPermission` call, in order — F-10 asserts none fire
  /// before disclosure consent (Play policy).
  final requestedPermissions = <PermissionKind>[];

  /// What `getInstalledApps` returns (F-10 app picker).
  List<InstalledApp> installedApps = const [];

  /// What `getAppIcons` returns (F-11 icon rows) — empty by default, so
  /// widgets exercise their no-icon glyph fallback.
  Map<String, List<int>> appIcons = const {};

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
  Future<void> requestPermission(PermissionKind kind) async {
    requestedPermissions.add(kind);
  }

  @override
  Future<List<InstalledApp>> getInstalledApps() async => installedApps;

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

  @override
  Future<void> grantAppPass(String packageName, int endEpochMs) async {
    final error = grantPassError;
    if (error != null) throw error;
    grantedPasses.add((packageName: packageName, endEpochMs: endEpochMs));
  }

  @override
  Future<void> ackEvents(int upToSeq) async {
    ackedSeqs.add(upToSeq);
  }

  @override
  Future<Map<String, List<int>>> getAppIcons(List<String> packageNames) async {
    return {
      for (final pkg in packageNames)
        if (appIcons.containsKey(pkg)) pkg: appIcons[pkg]!,
    };
  }

  Future<void> dispose() => _events.close();
}
