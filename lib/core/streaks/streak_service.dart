import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/repositories/streak_repository.dart';
import '../session/session_controller.dart' show clockProvider;
import 'streak_engine.dart';

/// What a completed session did to the streak — consumed by the
/// session-complete screen (SCREENS §7: streak row + token celebration).
class StreakOutcome {
  const StreakOutcome({
    required this.streakDays,
    required this.incremented,
    required this.tokensEarned,
  });

  static const none =
      StreakOutcome(streakDays: 0, incremented: false, tokensEarned: 0);

  final int streakDays;

  /// True when this session was the one that earned its day.
  final bool incremented;

  /// Lock-break tokens awarded by an exact milestone hit (0 normally).
  final int tokensEarned;
}

/// The four MVP "today" stats (fokus-specs §3.6).
class TodayStats {
  const TodayStats({
    required this.focusMinutes,
    required this.distractionsBlocked,
    required this.mostInterceptedApp,
    required this.currentStreak,
  });

  final int focusMinutes;
  final int distractionsBlocked;

  /// Human app name when resolvable, else the package name; null if no
  /// attempts today.
  final String? mostInterceptedApp;
  final int currentStreak;
}

/// Streak/token policy over the local DB. The streak itself is DERIVED from
/// session rows on every read (idempotent by construction, and timezone
/// changes automatically use the device's current zone — D-011); the
/// `streak_summary` row stores what cannot be derived (token balances) and
/// caches the derived values for cheap display reads.
class StreakService {
  StreakService(this._db, this._summaries, this._now);

  final FokusDatabase _db;
  final StreakRepository _summaries;
  final DateTime Function() _now;

  // ------------------------------------------------------------- derivation

  Future<({Set<DateTime> earned, Set<DateTime> excused})> _daySets() async {
    final rows = await (_db.select(_db.focusSessions)
          ..where((s) => s.status.equals(SessionStatus.completed.name)))
        .get();
    final earned = <DateTime>{};
    final excused = <DateTime>{};
    for (final row in rows) {
      final at = row.endTime ?? row.startTime;
      final day = StreakEngine.localDay(at);
      final isLockBreak = row.completionReason == CompletionReason.lockBreak;
      if (isLockBreak) {
        excused.add(day);
      } else if (StreakEngine.qualifies(
        actualMin: row.actualMin ?? 0,
        isLockBreak: false,
      )) {
        earned.add(day);
      }
    }
    return (earned: earned, excused: excused);
  }

  /// Decay-aware current streak (0 once a day was missed outright).
  Future<int> currentStreak() async {
    final days = await _daySets();
    return StreakEngine.currentStreak(
      earnedDays: days.earned,
      excusedDays: days.excused,
      today: _now(),
    );
  }

  // ------------------------------------------------------- completion hook

  /// Applies a just-completed session: recomputes the streak, awards
  /// milestone tokens, refreshes the summary cache. Idempotent — a replayed
  /// call for the same session finds the cache already at the derived value
  /// and awards nothing again.
  Future<StreakOutcome> onSessionCompleted(String sessionId) async {
    final row = await (_db.select(_db.focusSessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    if (row == null || row.status != SessionStatus.completed) {
      return StreakOutcome.none;
    }

    final days = await _daySets();
    final streak = StreakEngine.currentStreak(
      earnedDays: days.earned,
      excusedDays: days.excused,
      today: _now(),
    );
    final summary = await _summaries.getSummary();

    final qualifying = StreakEngine.qualifies(
      actualMin: row.actualMin ?? 0,
      isLockBreak: row.completionReason == CompletionReason.lockBreak,
    );
    final day = StreakEngine.localDay(row.endTime ?? _now());
    final alreadyApplied = summary.lastFocusDate == day;
    final incremented = qualifying && !alreadyApplied;

    var tokensEarned = 0;
    if (incremented) {
      tokensEarned = StreakEngine.tokensForMilestone(streak);
    }

    await _summaries.updateSummary(
      currentDays: streak,
      longestDays: streak > summary.longestDays ? streak : null,
      lastFocusDate: qualifying ? day : null,
      tokensAvailable:
          tokensEarned > 0 ? summary.tokensAvailable + tokensEarned : null,
      tokensLifetime:
          tokensEarned > 0 ? summary.tokensLifetime + tokensEarned : null,
    );

    return StreakOutcome(
      streakDays: streak,
      incremented: incremented,
      tokensEarned: tokensEarned,
    );
  }

  // ---------------------------------------------------------- lock-breaks

  /// A redemption is offered only when a token exists AND the calendar-week
  /// cap (max 3, CONTRACTS §4) is not exhausted. Week = ISO Mon–Sun, local.
  Future<bool> canRedeemLockBreak() async {
    final summary = await _summaries.getSummary();
    if (summary.tokensAvailable <= 0) return false;
    return await _redemptionsThisWeek() <
        FokusConstants.lockBreakWeeklyRedeemCap;
  }

  /// Consumes one token. Call AFTER the session persisted as
  /// completed-via-lockbreak (the excused day is derived from that row).
  Future<void> consumeToken() async {
    final summary = await _summaries.getSummary();
    if (summary.tokensAvailable <= 0) {
      throw StateError('no lock-break token to consume');
    }
    await _summaries.updateSummary(
      tokensAvailable: summary.tokensAvailable - 1,
    );
  }

  Future<int> _redemptionsThisWeek() async {
    final today = StreakEngine.localDay(_now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final rows = await (_db.select(_db.focusSessions)
          ..where(
            (s) =>
                s.status.equals(SessionStatus.completed.name) &
                s.completionReason.equals(CompletionReason.lockBreak.name) &
                s.endTime.isBiggerOrEqualValue(weekStart),
          ))
        .get();
    return rows.length;
  }

  // ---------------------------------------------------------------- today

  Future<TodayStats> todayStats() async {
    final dayStart = StreakEngine.localDay(_now());
    final dayEnd = dayStart.add(const Duration(days: 1));

    final sessions = await (_db.select(_db.focusSessions)
          ..where(
            (s) =>
                s.endTime.isBiggerOrEqualValue(dayStart) &
                s.endTime.isSmallerThanValue(dayEnd),
          ))
        .get();
    final focusMinutes =
        sessions.fold<int>(0, (sum, s) => sum + (s.actualMin ?? 0));

    final attempts = await (_db.select(_db.distractionAttempts)
          ..where(
            (a) =>
                a.ts.isBiggerOrEqualValue(dayStart) &
                a.ts.isSmallerThanValue(dayEnd),
          ))
        .get();

    String? topApp;
    if (attempts.isNotEmpty) {
      final counts = <String, int>{};
      for (final a in attempts) {
        counts[a.packageName] = (counts[a.packageName] ?? 0) + 1;
      }
      final topPkg = (counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
      final blocked = await (_db.select(_db.blockedApps)
            ..where((b) => b.packageName.equals(topPkg)))
          .getSingleOrNull();
      topApp = blocked?.appName ?? topPkg;
    }

    return TodayStats(
      focusMinutes: focusMinutes,
      distractionsBlocked: attempts.length,
      mostInterceptedApp: topApp,
      currentStreak: await currentStreak(),
    );
  }
}

final streakServiceProvider = Provider<StreakService>(
  (ref) => StreakService(
    ref.watch(databaseProvider),
    ref.watch(streakRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

/// Tokens offerable right now for a lock-break redemption: the available
/// balance when redeemable (token exists + weekly cap not hit), else 0.
/// Drives the graceful offer on the strict consequence screen (F-08/F-09).
final lockBreakOfferProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(streakServiceProvider);
  if (!await service.canRedeemLockBreak()) return 0;
  final summary = await ref.watch(streakRepositoryProvider).getSummary();
  return summary.tokensAvailable;
});
