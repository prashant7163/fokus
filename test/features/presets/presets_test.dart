import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/blocking_adapter.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/data/repositories/preset_repository.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/features/presets/application/schedule_sync_service.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

/// F-13: presets CRUD, schedule sync payload, and the schedule-auto-start
/// reconciliation (a restore event with config synthesizes the missing row —
/// the Dart half of "scheduled session auto-starts at local time").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FokusDatabase db;
  late FakeBlockingAdapter fake;
  late ProviderContainer container;
  late DateTime now;
  final t0 = DateTime(2026, 7, 2, 9, 0);

  setUp(() {
    now = t0;
    db = testDb();
    fake = FakeBlockingAdapter();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      blockingAdapterProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => now),
      tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await fake.dispose();
    await db.close();
  });

  PresetRepository repo() => container.read(presetRepositoryProvider);

  group('preset + schedule persistence', () {
    test('CRUD round-trips; deleting a preset removes its schedules',
        () async {
      final id = await repo().createPreset(
        name: 'Deep work',
        durationMin: 60,
        strictMode: true,
        recoveryEnabled: false,
        blockedPackages: ['com.instagram.android', 'com.tiktok'],
      );
      final preset = (await repo().getPresets()).single;
      expect(preset.name, 'Deep work');
      expect(PresetRepository.decodePackages(preset),
          ['com.instagram.android', 'com.tiktok']);
      expect(preset.recoveryEnabled, isFalse);

      final scheduleId = await repo().createSchedule(
        presetId: id,
        daysOfWeek: [1, 3, 5],
        startLocalTime: '07:30',
      );
      final schedule = (await repo().schedulesForPreset(id)).single;
      expect(PresetRepository.decodeDays(schedule), [1, 3, 5]);
      expect(schedule.startLocalTime, '07:30');
      expect(schedule.enabled, isTrue);

      await repo().updateSchedule(scheduleId, enabled: false);
      expect(await repo().enabledSchedules(), isEmpty);

      await repo().deletePreset(id);
      expect(await repo().getPresets(), isEmpty);
      expect(await repo().schedulesForPreset(id), isEmpty);
    });
  });

  group('schedule sync (D-022)', () {
    test('pushes enabled schedules joined with their presets', () async {
      final workId = await repo().createPreset(
        name: 'Deep work',
        durationMin: 60,
        strictMode: true,
        recoveryEnabled: false,
        blockedPackages: ['com.instagram.android'],
      );
      await repo().createSchedule(
        presetId: workId,
        daysOfWeek: [1, 2, 3, 4, 5],
        startLocalTime: '09:00',
      );
      final readId = await repo().createPreset(
        name: 'Evening reading',
        durationMin: 30,
        strictMode: false,
        recoveryEnabled: true,
        blockedPackages: [],
      );
      // Disabled → must NOT sync.
      await repo().createSchedule(
        presetId: readId,
        daysOfWeek: [6, 7],
        startLocalTime: '20:00',
        enabled: false,
      );

      await container.read(scheduleSyncProvider).sync();

      final synced = fake.syncedScheduleSets.single;
      expect(synced, hasLength(1));
      final s = synced.single;
      expect(s.presetName, 'Deep work');
      expect(s.durationMin, 60);
      expect(s.strictMode, isTrue);
      expect(s.recoveryEnabled, isFalse);
      expect(s.daysOfWeek, [1, 2, 3, 4, 5]);
      expect(s.startLocalTime, '09:00');
      expect(s.packages, ['com.instagram.android']);
    });
  });

  group('schedule auto-start reconciliation (D-022)', () {
    test(
        'restore event with config for an unknown session synthesizes the '
        'DB row and hydrates it', () async {
      final controller =
          container.read(sessionControllerProvider.notifier);
      // Let cold-start hydration settle (no session).
      await controller.syncWithClock();

      final started = t0.subtract(const Duration(minutes: 10));
      final end = t0.add(const Duration(minutes: 20));
      fake.emit(SessionRestoredEvent(
        sessionId: 'sched-abc',
        startedEpochMs: started.millisecondsSinceEpoch,
        endEpochMs: end.millisecondsSinceEpoch,
        taskAnchor: 'Deep work',
        strictMode: true,
        recoveryEnabled: false,
      ));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.active);
      expect(state.sessionId, 'sched-abc');
      expect(state.plannedMin, 30);
      expect(state.strictMode, isTrue);
      expect(state.recoveryEnabled, isFalse);
      expect(state.remaining, const Duration(minutes: 20));

      final row = await container
          .read(sessionRepositoryProvider)
          .getById('sched-abc');
      expect(row, isNotNull);
      expect(row!.status, SessionStatus.active);
      expect(row.plannedMin, 30);
      expect(row.taskAnchor, 'Deep work');
      expect(row.strictMode, isTrue);
    });

    test(
        'cold start with no event synthesizes from the native cache (D-024) '
        '— schedule started while the engine was dead', () async {
      // Native holds a schedule-started session; no DB row, no restore event.
      final started = t0.subtract(const Duration(minutes: 5));
      final end = t0.add(const Duration(minutes: 10));
      fake.activeNativeSession = SessionRestoredEvent(
        sessionId: 'sched-cold',
        startedEpochMs: started.millisecondsSinceEpoch,
        endEpochMs: end.millisecondsSinceEpoch,
        taskAnchor: 'Morning focus',
        strictMode: false,
        recoveryEnabled: true,
      );

      // Fresh container so build()'s cold-start hydrate runs against native.
      final freshContainer = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        blockingAdapterProvider.overrideWithValue(fake),
        clockProvider.overrideWithValue(() => now),
        tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
      ]);
      addTearDown(freshContainer.dispose);

      // Reading the provider triggers build() → cold-start _hydrate(null).
      freshContainer.read(sessionControllerProvider);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = freshContainer.read(sessionControllerProvider);
      expect(state.status, SessionStatus.active);
      expect(state.sessionId, 'sched-cold');
      expect(state.plannedMin, 15);
      final row = await freshContainer
          .read(sessionRepositoryProvider)
          .getById('sched-cold');
      expect(row, isNotNull);
      expect(row!.taskAnchor, 'Morning focus');
    });

    test('restore event without config for an unknown id stays idle',
        () async {
      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.syncWithClock();

      fake.emit(const SessionRestoredEvent(sessionId: 'ghost'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(sessionControllerProvider).status,
          SessionStatus.idle);
      expect(
        await container.read(sessionRepositoryProvider).getById('ghost'),
        isNull,
      );
    });

    test('a schedule-started session that already expired completes '
        'retroactively', () async {
      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.syncWithClock();

      final started = t0.subtract(const Duration(minutes: 45));
      final end = t0.subtract(const Duration(minutes: 15));
      fake.emit(SessionRestoredEvent(
        sessionId: 'sched-old',
        startedEpochMs: started.millisecondsSinceEpoch,
        endEpochMs: end.millisecondsSinceEpoch,
        strictMode: false,
        recoveryEnabled: true,
      ));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final row = await container
          .read(sessionRepositoryProvider)
          .getById('sched-old');
      expect(row!.status, SessionStatus.completed);
      expect(row.completionReason, CompletionReason.timerEnd);
    });
  });

  group('start passes the new config fields (D-022)', () {
    test('startedEpochMs and recoveryEnabled reach the native side',
        () async {
      await container.read(sessionControllerProvider.notifier).start(
            plannedMin: 30,
            recoveryEnabled: false,
          );
      final config = fake.startedConfigs.single;
      expect(config.startedEpochMs, t0.millisecondsSinceEpoch);
      expect(config.recoveryEnabled, isFalse);
      expect(
        container.read(sessionControllerProvider).recoveryEnabled,
        isFalse,
      );
    });
  });
}
