/// Pure achievement evaluator (F-15, fokus-specs §3.8).
///
/// No I/O, no clocks, no Riverpod — given fixture-friendly inputs it returns
/// the full set of earned codes. Idempotency ("unlock once") is the service's
/// job; this engine just answers "which achievements do these facts earn?".
library;

/// The eight achievements from fokus-specs §3.8. The persisted `code` column
/// stores [Enum.name] — renaming a value is a data migration.
enum AchievementCode {
  firstSession,
  earlyBird,
  nightOwl,
  distractionDestroyer,
  recoveryChampion,
  ironWill,
  examHero,
  twoWeekWarrior,
}

/// The facts of one COMPLETED session the engine cares about. Deliberately a
/// tiny value type (not the Drift row) so tests build fixtures in one line.
class SessionFacts {
  const SessionFacts({
    required this.startTime,
    required this.endTime,
    required this.actualMin,
    this.strictMode = false,
    this.viaLockBreak = false,
  });

  /// Local wall-clock start — Early Bird / Night Owl read its time of day.
  final DateTime startTime;

  /// Completion moment — anchors the Exam Hero rolling window.
  final DateTime endTime;

  /// Actual focused minutes (persisted `actualMin`).
  final int actualMin;

  final bool strictMode;

  /// Completed via a lock-break token (spec §3.5) — still a completion, but
  /// the strict session was NOT seen through, so Iron Will excludes it.
  final bool viaLockBreak;
}

/// Thresholds per fokus-specs §3.8.
abstract final class AchievementThresholds {
  /// Early Bird: session starts strictly before 07:00 local.
  static const int earlyBirdBeforeSecondOfDay = 7 * 3600;

  /// Night Owl: session starts strictly after 22:00 local.
  static const int nightOwlAfterSecondOfDay = 22 * 3600;

  static const int distractionDestroyerBlocks = 100;
  static const int recoveryChampionResumes = 10;
  static const int ironWillStrictCompletions = 10;
  static const int examHeroMinutes = 20 * 60;
  static const Duration examHeroWindow = Duration(days: 7);
  static const int twoWeekWarriorDays = 14;
}

abstract final class AchievementEngine {
  /// Evaluates all eight triggers over the given facts.
  ///
  /// [completedSessions] — every session with terminal status `completed`.
  /// [totalBlocks] — lifetime `distraction_attempts` count.
  /// [resumedRecoveries] — recovery events whose result is `resumed`.
  /// [currentStreakDays] — decay-aware streak from StreakService.
  static Set<AchievementCode> evaluate({
    required List<SessionFacts> completedSessions,
    required int totalBlocks,
    required int resumedRecoveries,
    required int currentStreakDays,
  }) {
    final earned = <AchievementCode>{};

    if (completedSessions.isNotEmpty) {
      earned.add(AchievementCode.firstSession);
    }
    if (completedSessions.any(
      (s) =>
          _secondOfDay(s.startTime) <
          AchievementThresholds.earlyBirdBeforeSecondOfDay,
    )) {
      earned.add(AchievementCode.earlyBird);
    }
    if (completedSessions.any(
      (s) =>
          _secondOfDay(s.startTime) >
          AchievementThresholds.nightOwlAfterSecondOfDay,
    )) {
      earned.add(AchievementCode.nightOwl);
    }
    if (totalBlocks >= AchievementThresholds.distractionDestroyerBlocks) {
      earned.add(AchievementCode.distractionDestroyer);
    }
    if (resumedRecoveries >= AchievementThresholds.recoveryChampionResumes) {
      earned.add(AchievementCode.recoveryChampion);
    }
    final strictCompletions = completedSessions
        .where((s) => s.strictMode && !s.viaLockBreak)
        .length;
    if (strictCompletions >= AchievementThresholds.ironWillStrictCompletions) {
      earned.add(AchievementCode.ironWill);
    }
    if (_examHero(completedSessions)) {
      earned.add(AchievementCode.examHero);
    }
    if (currentStreakDays >= AchievementThresholds.twoWeekWarriorDays) {
      earned.add(AchievementCode.twoWeekWarrior);
    }

    return earned;
  }

  /// Exam Hero: ≥ 20 h of actual focus inside SOME rolling 7-day window.
  /// Only windows ending at a session's completion can be maximal, so it
  /// suffices to anchor the window at each `endTime` and sum minutes of
  /// sessions ending within `(anchor − 7 d, anchor]`.
  static bool _examHero(List<SessionFacts> sessions) {
    for (final anchor in sessions) {
      final windowStart =
          anchor.endTime.subtract(AchievementThresholds.examHeroWindow);
      var minutes = 0;
      for (final s in sessions) {
        if (s.endTime.isAfter(windowStart) &&
            !s.endTime.isAfter(anchor.endTime)) {
          minutes += s.actualMin;
        }
      }
      if (minutes >= AchievementThresholds.examHeroMinutes) return true;
    }
    return false;
  }

  static int _secondOfDay(DateTime t) =>
      t.hour * 3600 + t.minute * 60 + t.second;
}
