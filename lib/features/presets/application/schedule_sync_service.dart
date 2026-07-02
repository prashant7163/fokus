import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/blocking/blocking_adapter.dart';
import '../../../core/blocking/providers.dart';
import '../../../core/data/providers.dart';
import '../../../core/data/repositories/preset_repository.dart';

/// Pushes the enabled schedules (joined with their presets) to the native
/// side, which persists them and arms WorkManager (F-13, D-022). Call after
/// EVERY preset/schedule mutation — the native mirror is replace-all, so a
/// missed sync means a stale alarm.
class ScheduleSyncService {
  ScheduleSyncService(this._presets, this._adapter);

  final PresetRepository _presets;
  final BlockingAdapter _adapter;

  Future<void> sync() async {
    final schedules = await _presets.enabledSchedules();
    final payload = <ScheduleSync>[];
    for (final schedule in schedules) {
      final preset = await _presets.presetById(schedule.presetId);
      if (preset == null) continue; // orphan row — nothing to arm.
      payload.add(
        ScheduleSync(
          id: schedule.id,
          presetName: preset.name,
          packages: PresetRepository.decodePackages(preset),
          durationMin: preset.durationMin,
          strictMode: preset.strictMode,
          recoveryEnabled: preset.recoveryEnabled,
          daysOfWeek: PresetRepository.decodeDays(schedule),
          startLocalTime: schedule.startLocalTime,
        ),
      );
    }
    await _adapter.syncSchedules(payload);
  }
}

final scheduleSyncProvider = Provider<ScheduleSyncService>(
  (ref) => ScheduleSyncService(
    ref.watch(presetRepositoryProvider),
    ref.watch(blockingAdapterProvider),
  ),
);
