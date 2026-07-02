import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/session/session_controller.dart'
    show clockProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fokus/features/achievements/application/achievement_engine.dart';
import 'package:fokus/features/achievements/application/achievements_service.dart';

import '../../core/data/test_db.dart';

/// F-15 service bar: unlock once even when re-evaluated (replayed completion,
/// process death mid-celebration), celebrate only in the inserting invocation.
void main() {
  late FokusDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 7, 10, 9, 30);

  setUp(() {
    db = testDb();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> completeSession({
    DateTime? start,
    int minutes = 25,
    bool strict = false,
  }) async {
    start ??= now.subtract(Duration(minutes: minutes));
    final sessions = container.read(sessionRepositoryProvider);
    final id = await sessions.createSession(
      plannedMin: minutes,
      strictMode: strict,
      startTime: start,
    );
    await sessions.completeSession(
      id,
      reason: CompletionReason.timerEnd,
      actualMin: minutes,
      endTime: start.add(Duration(minutes: minutes)),
    );
    return id;
  }

  test('first completed session unlocks First Session exactly once', () async {
    final service = container.read(achievementsServiceProvider);
    await completeSession();

    final first = await service.evaluateAndUnlock();
    expect(first, [AchievementCode.firstSession]);

    // Replayed evaluation: nothing new returned, nothing re-inserted,
    // original unlockedAt untouched.
    final rowsBefore =
        await container.read(achievementRepositoryProvider).getAll();
    final second = await service.evaluateAndUnlock();
    expect(second, isEmpty);
    final rowsAfter =
        await container.read(achievementRepositoryProvider).getAll();
    expect(rowsAfter.length, rowsBefore.length);
    expect(rowsAfter.single.code, AchievementCode.firstSession.name);
    expect(rowsAfter.single.unlockedAt, rowsBefore.single.unlockedAt);
  });

  test('later evaluation unlocks only the newly earned code', () async {
    final service = container.read(achievementsServiceProvider);
    final id = await completeSession();
    expect(await service.evaluateAndUnlock(), [AchievementCode.firstSession]);

    final attempts = container.read(distractionRepositoryProvider);
    for (var i = 0; i < 100; i++) {
      await attempts.logAttempt(
        sessionId: id,
        packageName: 'com.example.distraction',
        ts: now.subtract(Duration(minutes: 20, seconds: i)),
      );
    }

    expect(await service.evaluateAndUnlock(),
        [AchievementCode.distractionDestroyer]);
    expect(await service.evaluateAndUnlock(), isEmpty);
  });

  test('resumed recoveries feed Recovery Champion; exits do not', () async {
    final service = container.read(achievementsServiceProvider);
    final id = await completeSession();
    await service.evaluateAndUnlock(); // consume firstSession

    final recoveries = container.read(recoveryRepositoryProvider);
    for (var i = 0; i < 9; i++) {
      final eventId = await recoveries.startEvent(
          sessionId: id, type: RecoveryType.breathe);
      await recoveries.completeEvent(eventId, result: RecoveryResult.resumed);
    }
    final exited =
        await recoveries.startEvent(sessionId: id, type: RecoveryType.water);
    await recoveries.completeEvent(exited, result: RecoveryResult.exited);

    // 9 resumes + 1 exit — below threshold.
    expect(await service.evaluateAndUnlock(), isEmpty);

    final tenth = await recoveries.startEvent(
        sessionId: id, type: RecoveryType.stretch);
    await recoveries.completeEvent(tenth, result: RecoveryResult.resumed);
    expect(await service.evaluateAndUnlock(),
        [AchievementCode.recoveryChampion]);
  });

  test('aborted sessions never earn session-based achievements', () async {
    final sessions = container.read(sessionRepositoryProvider);
    final id = await sessions.createSession(
      plannedMin: 30,
      strictMode: true,
      startTime: DateTime(2026, 7, 10, 5, 0), // would be Early Bird
    );
    await sessions.abortSession(
      id,
      exitReason: ExitReason.emergency,
      actualMin: 5,
      endTime: DateTime(2026, 7, 10, 5, 5),
    );

    final service = container.read(achievementsServiceProvider);
    expect(await service.evaluateAndUnlock(), isEmpty);
  });
}
