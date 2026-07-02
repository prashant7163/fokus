import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/features/achievements/application/achievement_engine.dart';

/// F-15 done-criterion: all 8 spec §3.8 triggers fire — each exactly at its
/// threshold and not below it.
void main() {
  SessionFacts session({
    DateTime? start,
    int minutes = 25,
    bool strict = false,
    bool lockBreak = false,
    DateTime? end,
  }) {
    start ??= DateTime(2026, 7, 1, 9, 0);
    return SessionFacts(
      startTime: start,
      endTime: end ?? start.add(Duration(minutes: minutes)),
      actualMin: minutes,
      strictMode: strict,
      viaLockBreak: lockBreak,
    );
  }

  Set<AchievementCode> eval({
    List<SessionFacts> sessions = const [],
    int blocks = 0,
    int resumes = 0,
    int streak = 0,
  }) =>
      AchievementEngine.evaluate(
        completedSessions: sessions,
        totalBlocks: blocks,
        resumedRecoveries: resumes,
        currentStreakDays: streak,
      );

  group('First Session', () {
    test('no completed sessions earns nothing', () {
      expect(eval(), isEmpty);
    });

    test('one completed session fires', () {
      expect(eval(sessions: [session()]), {AchievementCode.firstSession});
    });
  });

  group('Early Bird (start < 7 am local)', () {
    test('06:59:59 start fires', () {
      final earned =
          eval(sessions: [session(start: DateTime(2026, 7, 1, 6, 59, 59))]);
      expect(earned, contains(AchievementCode.earlyBird));
    });

    test('07:00:00 start does not fire', () {
      final earned =
          eval(sessions: [session(start: DateTime(2026, 7, 1, 7, 0, 0))]);
      expect(earned, isNot(contains(AchievementCode.earlyBird)));
    });
  });

  group('Night Owl (start > 10 pm local)', () {
    test('22:00:01 start fires', () {
      final earned =
          eval(sessions: [session(start: DateTime(2026, 7, 1, 22, 0, 1))]);
      expect(earned, contains(AchievementCode.nightOwl));
    });

    test('22:00:00 start does not fire (strictly after)', () {
      final earned =
          eval(sessions: [session(start: DateTime(2026, 7, 1, 22, 0, 0))]);
      expect(earned, isNot(contains(AchievementCode.nightOwl)));
    });

    test('a 23:30 start never counts as Early Bird', () {
      final earned =
          eval(sessions: [session(start: DateTime(2026, 7, 1, 23, 30))]);
      expect(earned, contains(AchievementCode.nightOwl));
      expect(earned, isNot(contains(AchievementCode.earlyBird)));
    });
  });

  group('Distraction Destroyer (100 blocks)', () {
    test('99 blocks do not fire', () {
      expect(eval(blocks: 99),
          isNot(contains(AchievementCode.distractionDestroyer)));
    });

    test('100 blocks fire', () {
      expect(eval(blocks: 100),
          contains(AchievementCode.distractionDestroyer));
    });
  });

  group('Recovery Champion (10 resumes)', () {
    test('9 resumes do not fire', () {
      expect(
          eval(resumes: 9), isNot(contains(AchievementCode.recoveryChampion)));
    });

    test('10 resumes fire', () {
      expect(eval(resumes: 10), contains(AchievementCode.recoveryChampion));
    });
  });

  group('Iron Will (10 strict completions)', () {
    test('9 strict completions do not fire', () {
      final earned =
          eval(sessions: [for (var i = 0; i < 9; i++) session(strict: true)]);
      expect(earned, isNot(contains(AchievementCode.ironWill)));
    });

    test('10 strict completions fire', () {
      final earned =
          eval(sessions: [for (var i = 0; i < 10; i++) session(strict: true)]);
      expect(earned, contains(AchievementCode.ironWill));
    });

    test('lock-break completions of strict sessions do not count', () {
      final earned = eval(sessions: [
        for (var i = 0; i < 9; i++) session(strict: true),
        session(strict: true, lockBreak: true),
      ]);
      expect(earned, isNot(contains(AchievementCode.ironWill)));
    });

    test('non-strict completions do not count', () {
      final earned =
          eval(sessions: [for (var i = 0; i < 10; i++) session()]);
      expect(earned, isNot(contains(AchievementCode.ironWill)));
    });
  });

  group('Exam Hero (20 h within rolling 7 days)', () {
    test('1200 minutes inside 7 days fire', () {
      // 10 × 120 min across 5 days.
      final earned = eval(sessions: [
        for (var i = 0; i < 10; i++)
          session(
            start: DateTime(2026, 7, 1 + i ~/ 2, 8 + 4 * (i % 2)),
            minutes: 120,
          ),
      ]);
      expect(earned, contains(AchievementCode.examHero));
    });

    test('1199 minutes inside 7 days do not fire', () {
      // Same 5-day layout, one minute short in total.
      final earned = eval(sessions: [
        for (var i = 0; i < 9; i++)
          session(
            start: DateTime(2026, 7, 1 + i ~/ 2, 8 + 4 * (i % 2)),
            minutes: 120,
          ),
        session(start: DateTime(2026, 7, 5, 12), minutes: 119),
      ]);
      expect(earned, isNot(contains(AchievementCode.examHero)));
    });

    test('20 h spread just OUTSIDE a 7-day window does not fire', () {
      // Two 600-min sessions ending exactly 7 days apart: the earlier end sits
      // ON the window edge (anchor − 7 d) and is excluded — window is
      // half-open (anchor − 7 d, anchor].
      final earned = eval(sessions: [
        session(start: DateTime(2026, 7, 1, 9), end: DateTime(2026, 7, 1, 19), minutes: 600),
        session(start: DateTime(2026, 7, 8, 9), end: DateTime(2026, 7, 8, 19), minutes: 600),
      ]);
      expect(earned, isNot(contains(AchievementCode.examHero)));
    });

    test('20 h just INSIDE 7 days fires', () {
      final earned = eval(sessions: [
        session(start: DateTime(2026, 7, 1, 9), end: DateTime(2026, 7, 1, 19), minutes: 600),
        session(start: DateTime(2026, 7, 8, 8), end: DateTime(2026, 7, 8, 18, 59), minutes: 600),
      ]);
      expect(earned, contains(AchievementCode.examHero));
    });
  });

  group('Two Week Warrior (14-day streak)', () {
    test('13 days do not fire', () {
      expect(
          eval(streak: 13), isNot(contains(AchievementCode.twoWeekWarrior)));
    });

    test('14 days fire', () {
      expect(eval(streak: 14), contains(AchievementCode.twoWeekWarrior));
    });
  });

  test('all eight triggers can fire together', () {
    final earned = eval(
      sessions: [
        for (var i = 0; i < 10; i++)
          session(
            start: DateTime(2026, 7, 1 + i ~/ 2, i.isEven ? 6 : 23),
            minutes: 120,
            strict: true,
          ),
      ],
      blocks: 100,
      resumes: 10,
      streak: 14,
    );
    expect(earned, AchievementCode.values.toSet());
  });
}
