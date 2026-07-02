import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/data/repositories/session_repository.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/streaks/streak_service.dart';

import '../data/test_db.dart';
import '../session/fake_blocking_adapter.dart';

/// StreakService over a real in-memory DB, plus the controller integration
/// (completion hook + lock-break redemption).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FokusDatabase db;
  late FakeBlockingAdapter fake;
  late ProviderContainer container;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 7, 10, 9, 0);
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

  StreakService service() => container.read(streakServiceProvider);
  SessionRepository sessions() => container.read(sessionRepositoryProvider);
  SessionController controller() =>
      container.read(sessionControllerProvider.notifier);

  /// Seeds a terminal completed session ending on [end].
  Future<String> seedCompleted(
    DateTime end, {
    int actualMin = 25,
    CompletionReason reason = CompletionReason.timerEnd,
  }) async {
    final id = await sessions().createSession(
      plannedMin: actualMin,
      strictMode: false,
      startTime: end.subtract(Duration(minutes: actualMin)),
    );
    await sessions().completeSession(
      id,
      reason: reason,
      actualMin: actualMin,
      endTime: end,
    );
    return id;
  }

  group('onSessionCompleted', () {
    test('qualifying completion earns the day and caches the summary',
        () async {
      final id = await seedCompleted(now);
      final outcome = await service().onSessionCompleted(id);

      expect(outcome.streakDays, 1);
      expect(outcome.incremented, isTrue);
      expect(outcome.tokensEarned, 0);

      final summary =
          await container.read(streakRepositoryProvider).getSummary();
      expect(summary.currentDays, 1);
      expect(summary.longestDays, 1);
      expect(summary.lastFocusDate, DateTime(2026, 7, 10));
    });

    test('same day never counts twice; replay never double-awards', () async {
      final first = await seedCompleted(now);
      await service().onSessionCompleted(first);

      final second =
          await seedCompleted(now.add(const Duration(hours: 2)));
      final outcome = await service().onSessionCompleted(second);
      expect(outcome.streakDays, 1);
      expect(outcome.incremented, isFalse);

      // Replay of the first (buffered-event style) → also no-op.
      final replay = await service().onSessionCompleted(first);
      expect(replay.incremented, isFalse);
    });

    test('sub-10-min completion never earns (D-011)', () async {
      final id = await seedCompleted(now, actualMin: 9);
      final outcome = await service().onSessionCompleted(id);
      expect(outcome.streakDays, 0);
      expect(outcome.incremented, isFalse);
    });

    test('7-day run awards exactly 1 token, once', () async {
      for (var i = 6; i >= 1; i--) {
        final end = now.subtract(Duration(days: i));
        final id = await seedCompleted(end);
        await service().onSessionCompleted(id);
      }
      final id = await seedCompleted(now);
      final outcome = await service().onSessionCompleted(id);

      expect(outcome.streakDays, 7);
      expect(outcome.tokensEarned, 1);

      final summary =
          await container.read(streakRepositoryProvider).getSummary();
      expect(summary.tokensAvailable, 1);
      expect(summary.tokensLifetime, 1);

      // A second session the same day cannot re-award.
      final again = await seedCompleted(now.add(const Duration(hours: 1)));
      final outcome2 = await service().onSessionCompleted(again);
      expect(outcome2.tokensEarned, 0);
    });
  });

  group('lock-break redemption', () {
    Future<void> giveTokens(int n) => container
        .read(streakRepositoryProvider)
        .updateSummary(tokensAvailable: n, tokensLifetime: n);

    test('canRedeem requires a token', () async {
      expect(await service().canRedeemLockBreak(), isFalse);
      await giveTokens(1);
      expect(await service().canRedeemLockBreak(), isTrue);
    });

    test('weekly cap of 3 (CONTRACTS §4)', () async {
      await giveTokens(5);
      // Three redemptions already this ISO week (now is a Friday).
      for (var i = 0; i < 3; i++) {
        await seedCompleted(
          now.subtract(Duration(days: i)),
          reason: CompletionReason.lockBreak,
        );
      }
      expect(await service().canRedeemLockBreak(), isFalse);
    });

    test('last week\'s redemptions do not count against the cap', () async {
      await giveTokens(5);
      for (var i = 0; i < 3; i++) {
        await seedCompleted(
          now.subtract(Duration(days: 7 + i)),
          reason: CompletionReason.lockBreak,
        );
      }
      expect(await service().canRedeemLockBreak(), isTrue);
    });

    test(
        'controller.redeemLockBreak completes via lockBreak, decrements the '
        'token, preserves the streak', () async {
      // Earn a 1-day streak yesterday.
      final y = await seedCompleted(now.subtract(const Duration(days: 1)));
      await service().onSessionCompleted(y);
      await giveTokens(2);

      await controller().start(plannedMin: 30, taskAnchor: 'work');
      now = now.add(const Duration(minutes: 12));
      await controller().redeemLockBreak();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.completed);
      expect(state.completionReason, CompletionReason.lockBreak);
      // Lock-break never earns (D-011): streak stays at yesterday's 1.
      expect(state.streakOutcome!.incremented, isFalse);
      expect(state.streakOutcome!.streakDays, 1);

      final summary =
          await container.read(streakRepositoryProvider).getSummary();
      expect(summary.tokensAvailable, 1);

      final row = await sessions().getById(state.sessionId!);
      expect(row!.completionReason, CompletionReason.lockBreak);

      // Tomorrow a real session continues the streak across the excused day.
      now = now.add(const Duration(days: 1));
      final t = await seedCompleted(now);
      final outcome = await service().onSessionCompleted(t);
      expect(outcome.streakDays, 2);
      expect(outcome.incremented, isTrue);
    });

    test('redeem without a token is a programming error', () async {
      await controller().start(plannedMin: 30);
      await expectLater(controller().redeemLockBreak(), throwsStateError);
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.active, // session untouched
      );
    });
  });

  group('todayStats', () {
    test('the four MVP stats (spec §3.6)', () async {
      final id = await seedCompleted(now, actualMin: 25);
      await service().onSessionCompleted(id);

      final distractions = container.read(distractionRepositoryProvider);
      await container.read(appListsRepositoryProvider).addBlockedApp(
            packageName: 'com.instagram.android',
            appName: 'Instagram',
          );
      for (var i = 0; i < 3; i++) {
        await distractions.logAttempt(
          sessionId: id,
          packageName: 'com.instagram.android',
          ts: now.subtract(Duration(minutes: 10 + i)),
        );
      }
      await distractions.logAttempt(
        sessionId: id,
        packageName: 'com.tiktok',
        ts: now.subtract(const Duration(minutes: 5)),
      );
      // Yesterday's attempt must not count today.
      await distractions.logAttempt(
        sessionId: id,
        packageName: 'com.tiktok',
        ts: now.subtract(const Duration(days: 1)),
      );

      final stats = await service().todayStats();
      expect(stats.focusMinutes, 25);
      expect(stats.distractionsBlocked, 4);
      expect(stats.mostInterceptedApp, 'Instagram');
      expect(stats.currentStreak, 1);
    });
  });

  group('schema v2 (D-017)', () {
    test('recovery_events.note round-trips', () async {
      final id = await seedCompleted(now);
      final recovery = container.read(recoveryRepositoryProvider);
      final eventId = await recovery.startEvent(
        sessionId: id,
        type: RecoveryType.taskReset,
        startedAt: now,
      );
      await recovery.completeEvent(
        eventId,
        result: RecoveryResult.resumed,
        note: 'open the doc and write one sentence',
      );
      final events = await recovery.eventsForSession(id);
      expect(events.single.note, 'open the doc and write one sentence');
    });
  });
}
