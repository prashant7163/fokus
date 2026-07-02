import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'blocking_adapter.dart';
import 'channel_blocking_adapter.dart';

/// The app-wide blocking facade. Tests override this with a fake adapter.
final blockingAdapterProvider = Provider<BlockingAdapter>(
  (ref) => ChannelBlockingAdapter(),
);

/// Live permission snapshot (F-10 checklist, F-11 limited-mode banner, F-12
/// health card). Consumers invalidate it when returning from settings.
final permissionStatusProvider = FutureProvider.autoDispose<PermissionState>(
  (ref) => ref.watch(blockingAdapterProvider).getPermissionStatus(),
);

/// Launcher icons for the currently blocked apps, keyed by package (F-11
/// hero/config/active rows; D-019). Missing icons → callers show a glyph.
final blockedAppIconsProvider =
    FutureProvider.autoDispose<Map<String, Uint8List>>((ref) async {
  final packages =
      await ref.watch(appListsRepositoryProvider).getBlockedPackageNames();
  if (packages.isEmpty) return const {};
  final raw = await ref.watch(blockingAdapterProvider).getAppIcons(packages);
  return {
    for (final entry in raw.entries) entry.key: Uint8List.fromList(entry.value),
  };
});
