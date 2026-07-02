import '../constants.dart';

/// Pure streak rules — fokus-specs §3.5 with the D-011 rulings baked in.
/// No IO, no clock, no zone lookups: callers pass local-time values, so the
/// "timezone changes use the device's *current* zone" rule holds by
/// construction (everything is derived at read time from session rows).
///
/// Vocabulary:
/// - **earned day** — has ≥ 1 completed session of ≥ 10 min that is NOT a
///   lock-break redemption. Only earned days increment the streak.
/// - **excused day** — has a completed-via-lockbreak session. It bridges the
///   chain (streak neither resets nor increments — D-011).
abstract final class StreakEngine {
  /// The local calendar day of [local] (midnight, retaining no time-of-day).
  static DateTime localDay(DateTime local) =>
      DateTime(local.year, local.month, local.day);

  /// Current streak in earned days.
  ///
  /// The chain is the maximal run of consecutive alive days (earned or
  /// excused) ending on [today] or yesterday — a day with no session only
  /// breaks the streak once it is over, so "yesterday earned, today still
  /// empty" keeps the streak visible. Excused days bridge but never count.
  static int currentStreak({
    required Set<DateTime> earnedDays,
    required Set<DateTime> excusedDays,
    required DateTime today,
  }) {
    bool alive(DateTime d) => earnedDays.contains(d) || excusedDays.contains(d);

    var cursor = localDay(today);
    if (!alive(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!alive(cursor)) return 0;
    }

    var earned = 0;
    while (alive(cursor)) {
      if (earnedDays.contains(cursor)) earned++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return earned;
  }

  /// Whether a completed session earns its day (D-011: lock-breaks and
  /// sub-10-min sessions never earn).
  static bool qualifies({required int actualMin, required bool isLockBreak}) =>
      !isLockBreak && actualMin >= FokusConstants.streakQualifyingSessionMin;

  /// Tokens awarded when the streak reaches [streakDays] — exact milestone
  /// hits only (CONTRACTS §4: 7 → 1 … 100 → 10), 0 otherwise.
  static int tokensForMilestone(int streakDays) =>
      FokusConstants.lockBreakMilestones[streakDays] ?? 0;
}
