import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database.dart';
import '../../../core/data/providers.dart';
import '../../../core/data/repositories/achievement_repository.dart';
import '../../../core/data/repositories/distraction_repository.dart';
import '../../../core/data/repositories/recovery_repository.dart';
import '../../../core/data/repositories/session_repository.dart';
import '../../../core/session/session_controller.dart' show clockProvider;
import '../../../core/streaks/streak_service.dart';
import 'achievement_engine.dart';

/// Orchestrates F-15: reads the local facts, runs the pure engine, persists
/// new unlocks, and returns ONLY what this invocation unlocked.
///
/// "Unlock once, celebrate once" (fokus-specs §3.8): the insert is
/// insert-or-ignore keyed on `code`, so re-evaluation (replayed completion,
/// process death mid-celebration, parallel calls) never re-inserts — and the
/// celebration renders only in the invocation whose insert actually landed.
class AchievementsService {
  AchievementsService({
    required SessionRepository sessions,
    required DistractionRepository distractions,
    required RecoveryRepository recoveries,
    required StreakService streaks,
    required AchievementRepository achievements,
    required DateTime Function() now,
  })  : _sessions = sessions,
        _distractions = distractions,
        _recoveries = recoveries,
        _streaks = streaks,
        _achievements = achievements,
        _now = now;

  final SessionRepository _sessions;
  final DistractionRepository _distractions;
  final RecoveryRepository _recoveries;
  final StreakService _streaks;
  final AchievementRepository _achievements;
  final DateTime Function() _now;

  /// Evaluates all triggers and unlocks anything newly earned. Returns the
  /// newly unlocked codes in enum order (empty on re-evaluation).
  Future<List<AchievementCode>> evaluateAndUnlock() async {
    final earned = AchievementEngine.evaluate(
      completedSessions: await _completedSessionFacts(),
      totalBlocks: await _distractions.totalCount(),
      resumedRecoveries: (await _recoveries.completedEvents())
          .where((e) => e.result == RecoveryResult.resumed)
          .length,
      currentStreakDays: await _streaks.currentStreak(),
    );

    final already = await _achievements.unlockedCodes();
    final now = _now();
    final newlyUnlocked = <AchievementCode>[];
    for (final code in AchievementCode.values) {
      if (!earned.contains(code) || already.contains(code.name)) continue;
      // insertIfAbsent re-checks at the DB layer: only the call that actually
      // inserted the row celebrates.
      if (await _achievements.insertIfAbsent(code.name, now)) {
        newlyUnlocked.add(code);
      }
    }
    return newlyUnlocked;
  }

  Future<List<SessionFacts>> _completedSessionFacts() async {
    // Wide startTime window = all sessions ever (no dedicated "all completed"
    // query exists and F-15 must not grow core repositories beyond need).
    final rows = await _sessions.sessionsBetween(
      DateTime(2000),
      _now().add(const Duration(days: 1)),
    );
    return [
      for (final row in rows)
        if (row.status == SessionStatus.completed)
          SessionFacts(
            startTime: row.startTime,
            endTime: row.endTime ?? row.startTime,
            actualMin: row.actualMin ?? 0,
            strictMode: row.strictMode,
            viaLockBreak: row.completionReason == CompletionReason.lockBreak,
          ),
    ];
  }
}

final achievementsServiceProvider = Provider<AchievementsService>(
  (ref) => AchievementsService(
    sessions: ref.watch(sessionRepositoryProvider),
    distractions: ref.watch(distractionRepositoryProvider),
    recoveries: ref.watch(recoveryRepositoryProvider),
    streaks: ref.watch(streakServiceProvider),
    achievements: ref.watch(achievementRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);
