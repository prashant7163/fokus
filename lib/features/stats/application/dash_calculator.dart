import '../../../core/data/database.dart';

/// Pure day/week/month bucketing for the stats dashboard (F-14,
/// fokus-specs §3.6). No I/O — callers fetch rows via the repositories and
/// feed them in; every date computation uses the injected `now` (local time).

/// The dashboard's segmented ranges.
enum DashRange { day, week, month }

/// A closed date window `[start, end)` plus its bucket boundaries.
///
/// - [DashRange.day]: today (local), 24 hourly buckets.
/// - [DashRange.week]: this ISO week (Mon–Sun, matching streaks), 7 daily
///   buckets.
/// - [DashRange.month]: this calendar month, one bucket per day.
///
/// Buckets are constructed from calendar components (never `Duration`
/// arithmetic), so DST transitions cannot shift a boundary off midnight.
class DashWindow {
  const DashWindow._(this.range, this.start, this.end, this.bucketStarts);

  final DashRange range;
  final DateTime start;

  /// Exclusive.
  final DateTime end;

  /// Sorted, first == [start]; bucket i covers
  /// `[bucketStarts[i], bucketStarts[i+1])` (last bucket ends at [end]).
  final List<DateTime> bucketStarts;

  factory DashWindow.of(DashRange range, DateTime now) {
    switch (range) {
      case DashRange.day:
        final day = DateTime(now.year, now.month, now.day);
        return DashWindow._(
          range,
          day,
          DateTime(day.year, day.month, day.day + 1),
          [for (var h = 0; h < 24; h++) DateTime(day.year, day.month, day.day, h)],
        );
      case DashRange.week:
        final day = DateTime(now.year, now.month, now.day);
        final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
        return DashWindow._(
          range,
          monday,
          DateTime(monday.year, monday.month, monday.day + 7),
          [
            for (var d = 0; d < 7; d++)
              DateTime(monday.year, monday.month, monday.day + d),
          ],
        );
      case DashRange.month:
        final first = DateTime(now.year, now.month);
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        return DashWindow._(
          range,
          first,
          DateTime(now.year, now.month + 1),
          [
            for (var d = 1; d <= daysInMonth; d++)
              DateTime(now.year, now.month, d),
          ],
        );
    }
  }

  bool contains(DateTime ts) => !ts.isBefore(start) && ts.isBefore(end);

  /// Index of the bucket containing [ts], or -1 when outside the window.
  /// Linear scan over ≤ 31 sorted boundaries — trivially DST-proof.
  int bucketIndex(DateTime ts) {
    if (!contains(ts)) return -1;
    for (var i = bucketStarts.length - 1; i >= 0; i--) {
      if (!ts.isBefore(bucketStarts[i])) return i;
    }
    return -1;
  }
}

/// One bar-chart bucket.
class DashBucket {
  const DashBucket({
    required this.start,
    this.focusMinutes = 0,
    this.completed = 0,
    this.endedEarly = 0,
    this.distractions = 0,
  });

  final DateTime start;
  final int focusMinutes;
  final int completed;

  /// aborted + failed-permissions — every terminal session that did not
  /// complete. Shown neutrally ("ended early"), never as guilt (SCREENS §6).
  final int endedEarly;
  final int distractions;
}

/// Everything the dashboard section renders for one range.
class DashData {
  const DashData({
    required this.window,
    required this.buckets,
    required this.totalFocusMinutes,
    required this.totalCompleted,
    required this.totalEndedEarly,
    required this.totalDistractions,
    required this.recoveriesResumed,
    required this.recoveriesExited,
  });

  final DashWindow window;
  final List<DashBucket> buckets;
  final int totalFocusMinutes;
  final int totalCompleted;
  final int totalEndedEarly;
  final int totalDistractions;
  final int recoveriesResumed;
  final int recoveriesExited;

  /// Null when the range has no completed recovery events.
  double? get resumeRate {
    final samples = recoveriesResumed + recoveriesExited;
    if (samples == 0) return null;
    return recoveriesResumed / samples;
  }

  bool get isEmpty =>
      totalFocusMinutes == 0 &&
      totalCompleted == 0 &&
      totalEndedEarly == 0 &&
      totalDistractions == 0;
}

/// Buckets rows into [window].
///
/// Attribution (all local time):
/// - a session counts in the bucket of its **endTime** (terminal moment —
///   matches the today card, and a session crossing midnight lands on the
///   day it finished);
/// - a distraction attempt counts by its **ts**;
/// - a recovery event counts by its **startedAt**.
///
/// Rows outside the window are ignored, so callers may over-fetch (e.g. pad
/// the session query by the max session length to catch midnight-crossers).
DashData computeDashData({
  required DashWindow window,
  required List<FocusSession> sessions,
  required List<DistractionAttempt> attempts,
  required List<RecoveryEvent> recoveryEvents,
}) {
  final n = window.bucketStarts.length;
  final focusMinutes = List<int>.filled(n, 0);
  final completed = List<int>.filled(n, 0);
  final endedEarly = List<int>.filled(n, 0);
  final distractions = List<int>.filled(n, 0);

  for (final s in sessions) {
    final end = s.endTime;
    if (end == null) continue; // still running — nothing terminal to count
    final i = window.bucketIndex(end);
    if (i < 0) continue;
    focusMinutes[i] += s.actualMin ?? 0;
    switch (s.status) {
      case SessionStatus.completed:
        completed[i]++;
      case SessionStatus.aborted:
      case SessionStatus.failedPermissions:
        endedEarly[i]++;
      case SessionStatus.idle:
      case SessionStatus.pendingStart:
      case SessionStatus.active:
      case SessionStatus.recoveryInProgress:
        break; // non-terminal rows never carry an endTime; defensive
    }
  }

  for (final a in attempts) {
    final i = window.bucketIndex(a.ts);
    if (i >= 0) distractions[i]++;
  }

  var resumed = 0;
  var exited = 0;
  for (final e in recoveryEvents) {
    if (!window.contains(e.startedAt)) continue;
    switch (e.result) {
      case RecoveryResult.resumed:
        resumed++;
      case RecoveryResult.exited:
        exited++;
      case null:
        break; // in progress — not a sample yet
    }
  }

  int sum(List<int> xs) => xs.fold(0, (a, b) => a + b);
  return DashData(
    window: window,
    buckets: [
      for (var i = 0; i < n; i++)
        DashBucket(
          start: window.bucketStarts[i],
          focusMinutes: focusMinutes[i],
          completed: completed[i],
          endedEarly: endedEarly[i],
          distractions: distractions[i],
        ),
    ],
    totalFocusMinutes: sum(focusMinutes),
    totalCompleted: sum(completed),
    totalEndedEarly: sum(endedEarly),
    totalDistractions: sum(distractions),
    recoveriesResumed: resumed,
    recoveriesExited: exited,
  );
}
