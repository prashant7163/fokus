/// Business constants — single source of truth per docs/CONTRACTS.md §4.
/// Changing any value here is a CONTRACTS change (requires a DECISIONS.md entry).
abstract final class FokusConstants {
  /// Offered session durations in minutes (plus custom).
  static const List<int> sessionDurationsMin = [15, 30, 60, 120];

  /// Custom duration bounds in minutes (fokus-specs.md §3.1).
  static const int customDurationMinMin = 5;
  static const int customDurationMaxMin = 480;

  /// Task anchor max length in characters (fokus-specs.md §3.1).
  static const int taskAnchorMaxChars = 80;

  /// A day qualifies for the streak with ≥ 1 completed session of this length.
  static const int streakQualifyingSessionMin = 10;

  /// Lock-break token earn milestones: streak days → tokens awarded.
  static const Map<int, int> lockBreakMilestones = {
    7: 1,
    14: 2,
    30: 3,
    60: 5,
    100: 10,
  };

  /// Max lock-break redemptions per calendar week.
  static const int lockBreakWeeklyRedeemCap = 3;

  /// Post-session micro-feedback sampling: 1 in N sessions.
  static const int feedbackSamplingOneIn = 3;
}
