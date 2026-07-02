import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/streaks/streak_engine.dart';

/// Pure streak rules — fokus-specs §3.5 + D-011. These carry the product
/// (CONVENTIONS testing bar: unit-tested, no exceptions).
void main() {
  DateTime d(int day) => DateTime(2026, 7, day);

  group('localDay / day boundary', () {
    test('one minute before and after midnight land on different days', () {
      expect(
        StreakEngine.localDay(DateTime(2026, 7, 2, 23, 59)),
        DateTime(2026, 7, 2),
      );
      expect(
        StreakEngine.localDay(DateTime(2026, 7, 3, 0, 1)),
        DateTime(2026, 7, 3),
      );
    });

    test('a session completing at 00:01 counts for the NEW day', () {
      // The user focused across midnight — the completion timestamp decides.
      final earned = {StreakEngine.localDay(DateTime(2026, 7, 3, 0, 1))};
      expect(
        StreakEngine.currentStreak(
          earnedDays: earned,
          excusedDays: const {},
          today: DateTime(2026, 7, 3, 9, 0),
        ),
        1,
      );
    });

    test(
        'timezone semantics: values are local wall-clock, so a zone change '
        'simply re-derives with the current zone (D-011)', () {
      // The engine never sees a zone — callers pass local DateTimes. A user
      // flying UTC+2 → UTC-5 gets days computed in the new zone on next read;
      // the same instant can legitimately fall on the prior local day.
      final instantUtc = DateTime.utc(2026, 7, 3, 1, 30);
      final asZurich = instantUtc.add(const Duration(hours: 2)); // 03:30 Jul 3
      final asNewYork =
          instantUtc.subtract(const Duration(hours: 5)); // 20:30 Jul 2
      expect(StreakEngine.localDay(asZurich), DateTime(2026, 7, 3));
      expect(StreakEngine.localDay(asNewYork), DateTime(2026, 7, 2));
    });
  });

  group('currentStreak', () {
    test('empty history → 0', () {
      expect(
        StreakEngine.currentStreak(
          earnedDays: const {},
          excusedDays: const {},
          today: d(10),
        ),
        0,
      );
    });

    test('run of earned days ending today', () {
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(8), d(9), d(10)},
          excusedDays: const {},
          today: d(10),
        ),
        3,
      );
    });

    test('yesterday earned, today still empty → streak not yet broken', () {
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(8), d(9)},
          excusedDays: const {},
          today: d(10),
        ),
        2,
      );
    });

    test('a fully missed day breaks the streak', () {
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(6), d(7), d(10)},
          excusedDays: const {},
          today: d(10),
        ),
        1, // only the new run counts
      );
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(6), d(7)},
          excusedDays: const {},
          today: d(10),
        ),
        0, // gap on the 8th/9th, nothing since
      );
    });

    test('excused day bridges but never counts (D-011)', () {
      // Mon earned, Tue lock-break, Wed earned → 2 earned days, unbroken.
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(6), d(8)},
          excusedDays: {d(7)},
          today: d(8),
        ),
        2,
      );
    });

    test('two consecutive excused days still bridge', () {
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(5), d(8)},
          excusedDays: {d(6), d(7)},
          today: d(8),
        ),
        2,
      );
    });

    test('chain ending on an excused yesterday keeps the earned count', () {
      // Mon earned, Tue excused, Wed (today) still empty.
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(6)},
          excusedDays: {d(7)},
          today: d(8),
        ),
        1,
      );
    });

    test('a day both earned and excused counts as earned', () {
      // Lock-break at noon, real completed session in the evening.
      expect(
        StreakEngine.currentStreak(
          earnedDays: {d(7)},
          excusedDays: {d(7)},
          today: d(7),
        ),
        1,
      );
    });
  });

  group('qualifies (D-011: never earn)', () {
    test('≥ 10 min real completion earns', () {
      expect(StreakEngine.qualifies(actualMin: 10, isLockBreak: false), isTrue);
    });
    test('sub-10-min never earns', () {
      expect(StreakEngine.qualifies(actualMin: 9, isLockBreak: false), isFalse);
    });
    test('lock-break never earns, regardless of length', () {
      expect(StreakEngine.qualifies(actualMin: 45, isLockBreak: true), isFalse);
    });
  });

  group('milestones (CONTRACTS §4)', () {
    test('exact hits award, everything else is 0', () {
      expect(StreakEngine.tokensForMilestone(7), 1);
      expect(StreakEngine.tokensForMilestone(14), 2);
      expect(StreakEngine.tokensForMilestone(30), 3);
      expect(StreakEngine.tokensForMilestone(60), 5);
      expect(StreakEngine.tokensForMilestone(100), 10);
      expect(StreakEngine.tokensForMilestone(6), 0);
      expect(StreakEngine.tokensForMilestone(8), 0);
      expect(StreakEngine.tokensForMilestone(0), 0);
    });
  });
}
