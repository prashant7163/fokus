import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/prefs.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/features/suggestions/application/suggestion_engine.dart';
import 'package:fokus/features/suggestions/application/suggestion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

/// F-17 done-criterion: suggestions from ≥ 2 weeks of fixture data match
/// expected. Engine rules are pure; the service adds opt-in, the 14-day
/// gate, and the one-per-day cap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SuggestionEngine (pure rules, spec §3.10)', () {
    final now = DateTime(2026, 7, 14, 12, 0);

    test('distraction window fires at ≥4 of last 7 days, not at 3', () {
      List<DateTime> cluster(int days, int hour) => [
            for (var d = 1; d <= days; d++)
              DateTime(2026, 7, 14 - d, hour, 15),
          ];
      expect(SuggestionEngine.distractionWindow(cluster(4, 21), now), 21);
      expect(SuggestionEngine.distractionWindow(cluster(3, 21), now), isNull);
      // Same-day repeats count once.
      final sameDay = [
        for (var i = 0; i < 10; i++) DateTime(2026, 7, 13, 21, i),
      ];
      expect(SuggestionEngine.distractionWindow(sameDay, now), isNull);
      // Attempts older than 7 days are ignored.
      expect(
        SuggestionEngine.distractionWindow(
          [for (var d = 10; d <= 14; d++) DateTime(2026, 7, 14 - d, 21)],
          now,
        ),
        isNull,
      );
    });

    test('optimal length needs a ≥25-point gap and 3 samples each side', () {
      List<SessionFact> mix({
        required int shortWins,
        required int shortTotal,
        required int longWins,
        required int longTotal,
      }) =>
          [
            for (var i = 0; i < shortTotal; i++)
              SessionFact(
                plannedMin: 30,
                completed: i < shortWins,
                startTime: DateTime(2026, 7, 1 + i),
              ),
            for (var i = 0; i < longTotal; i++)
              SessionFact(
                plannedMin: 90,
                completed: i < longWins,
                startTime: DateTime(2026, 7, 1 + i),
              ),
          ];
      // 100% vs 50% → suggest 30.
      expect(
        SuggestionEngine.optimalLength(
          mix(shortWins: 4, shortTotal: 4, longWins: 2, longTotal: 4),
        ),
        30,
      );
      // 75% vs 75% → nothing.
      expect(
        SuggestionEngine.optimalLength(
          mix(shortWins: 3, shortTotal: 4, longWins: 3, longTotal: 4),
        ),
        isNull,
      );
      // Too few long samples → nothing.
      expect(
        SuggestionEngine.optimalLength(
          mix(shortWins: 4, shortTotal: 4, longWins: 0, longTotal: 2),
        ),
        isNull,
      );
    });

    test('recovery ordering re-ranks sampled modules only', () {
      final order = SuggestionEngine.recoveryOrder({
        RecoveryType.breathe: (resumed: 2, total: 5), // 40%
        RecoveryType.water: (resumed: 5, total: 5), // 100%
        RecoveryType.taskReset: (resumed: 1, total: 2), // under-sampled
      });
      // water outranks breathe among the sampled slots (positions 0 and 3);
      // taskReset/stretch/shrink keep their default positions.
      expect(order, [
        RecoveryType.water,
        RecoveryType.taskReset,
        RecoveryType.stretch,
        RecoveryType.breathe,
        RecoveryType.changeDuration,
      ]);
    });

    test('14-day history gate', () {
      expect(
        SuggestionEngine.hasEnoughHistory(
          now.subtract(const Duration(days: 14)),
          now,
        ),
        isTrue,
      );
      expect(
        SuggestionEngine.hasEnoughHistory(
          now.subtract(const Duration(days: 13)),
          now,
        ),
        isFalse,
      );
      expect(SuggestionEngine.hasEnoughHistory(null, now), isFalse);
    });
  });

  group('SuggestionService (opt-in, daily cap)', () {
    late FokusDatabase db;
    late FakeBlockingAdapter fake;
    late ProviderContainer container;
    late DateTime now;
    final t0 = DateTime(2026, 7, 20, 12, 0);

    Future<void> setUpContainer({required bool optIn}) async {
      SharedPreferences.setMockInitialValues(
        {PrefKeys.smartSuggestions: optIn},
      );
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        blockingAdapterProvider.overrideWithValue(fake),
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
        tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
      ]);
    }

    setUp(() {
      now = t0;
      db = testDb();
      fake = FakeBlockingAdapter();
    });

    tearDown(() async {
      container.dispose();
      await fake.dispose();
      await db.close();
    });

    /// ≥14 days of sessions + a 21:00 attempt cluster on 5 recent days.
    Future<void> seedTwoWeeks() async {
      final sessions = container.read(sessionRepositoryProvider);
      for (var d = 0; d < 15; d++) {
        final start = t0.subtract(Duration(days: d, hours: 3));
        final id = await sessions.createSession(
          plannedMin: 30,
          strictMode: false,
          startTime: start,
        );
        await sessions.completeSession(
          id,
          reason: CompletionReason.timerEnd,
          actualMin: 30,
          endTime: start.add(const Duration(minutes: 30)),
        );
        if (d >= 1 && d <= 5) {
          await container.read(distractionRepositoryProvider).logAttempt(
                sessionId: id,
                packageName: 'com.tiktok',
                ts: DateTime(t0.year, t0.month, t0.day - d, 21, 10),
              );
        }
      }
    }

    test('opted out → nothing, ever', () async {
      await setUpContainer(optIn: false);
      await seedTwoWeeks();
      expect(
        await container.read(suggestionServiceProvider).todaysSuggestion(),
        isNull,
      );
    });

    test('fixture data → distraction-window suggestion at 21:00, max 1/day',
        () async {
      await setUpContainer(optIn: true);
      await seedTwoWeeks();
      final service = container.read(suggestionServiceProvider);

      final first = await service.todaysSuggestion();
      expect(first, isNotNull);
      expect(first!.type, 'distraction_window');
      expect(first.hour, 21);

      // Same day again → the SAME insight, no second row.
      final again = await service.todaysSuggestion();
      expect(again!.id, first.id);

      // Dismissed → gone for the day.
      await service.dismiss(first.id);
      expect(await service.todaysSuggestion(), isNull);
    });

    test('under 14 days of history → nothing', () async {
      await setUpContainer(optIn: true);
      final sessions = container.read(sessionRepositoryProvider);
      for (var d = 0; d < 5; d++) {
        final id = await sessions.createSession(
          plannedMin: 30,
          strictMode: false,
          startTime: t0.subtract(Duration(days: d)),
        );
        await sessions.completeSession(
          id,
          reason: CompletionReason.timerEnd,
          actualMin: 30,
        );
      }
      expect(
        await container.read(suggestionServiceProvider).todaysSuggestion(),
        isNull,
      );
    });
  });
}
