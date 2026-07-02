import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/features/stats/application/dash_calculator.dart';

/// F-14 bucketing: day (hourly), week (Mon–Sun daily), month (daily) —
/// including local-day boundaries and out-of-window rows.
void main() {
  // Friday 2026-07-10, 14:30 local.
  final now = DateTime(2026, 7, 10, 14, 30);

  FocusSession session({
    required String id,
    required SessionStatus status,
    required DateTime start,
    DateTime? end,
    int? actualMin,
  }) =>
      FocusSession(
        id: id,
        status: status,
        startTime: start,
        endTime: end,
        plannedMin: 25,
        actualMin: actualMin,
        strictMode: false,
      );

  DistractionAttempt attempt(int id, DateTime ts) => DistractionAttempt(
        id: id,
        sessionId: 's1',
        packageName: 'com.tiktok',
        ts: ts,
        recoveryInvoked: false,
      );

  RecoveryEvent recovery(int id, DateTime startedAt, RecoveryResult? result) =>
      RecoveryEvent(
        id: id,
        sessionId: 's1',
        type: RecoveryType.breathe,
        startedAt: startedAt,
        completedAt: result == null ? null : startedAt,
        result: result,
      );

  group('DashWindow', () {
    test('day: today midnight-to-midnight, 24 hourly buckets', () {
      final w = DashWindow.of(DashRange.day, now);
      expect(w.start, DateTime(2026, 7, 10));
      expect(w.end, DateTime(2026, 7, 11));
      expect(w.bucketStarts, hasLength(24));
      expect(w.bucketIndex(DateTime(2026, 7, 10)), 0); // inclusive start
      expect(w.bucketIndex(DateTime(2026, 7, 10, 9, 59)), 9);
      expect(w.bucketIndex(DateTime(2026, 7, 10, 23, 59, 59)), 23);
      expect(w.bucketIndex(DateTime(2026, 7, 11)), -1); // exclusive end
      expect(w.bucketIndex(DateTime(2026, 7, 9, 23, 59)), -1);
    });

    test('week: Monday-anchored (ISO, matches streaks), 7 daily buckets', () {
      final w = DashWindow.of(DashRange.week, now);
      expect(w.start, DateTime(2026, 7, 6)); // Monday
      expect(w.end, DateTime(2026, 7, 13));
      expect(w.bucketStarts, hasLength(7));
      expect(w.bucketIndex(DateTime(2026, 7, 6)), 0);
      // Day boundary: 23:59 belongs to its day, midnight to the next.
      expect(w.bucketIndex(DateTime(2026, 7, 8, 23, 59)), 2);
      expect(w.bucketIndex(DateTime(2026, 7, 9)), 3);
      expect(w.bucketIndex(DateTime(2026, 7, 12, 23, 59, 59)), 6); // Sunday
      expect(w.bucketIndex(DateTime(2026, 7, 13)), -1);
    });

    test('week window is Monday-anchored even ON a Monday', () {
      final w = DashWindow.of(DashRange.week, DateTime(2026, 7, 6, 0, 5));
      expect(w.start, DateTime(2026, 7, 6));
      expect(w.end, DateTime(2026, 7, 13));
    });

    test('month: one bucket per calendar day, month-length aware', () {
      final july = DashWindow.of(DashRange.month, now);
      expect(july.start, DateTime(2026, 7));
      expect(july.end, DateTime(2026, 8));
      expect(july.bucketStarts, hasLength(31));
      expect(july.bucketIndex(DateTime(2026, 7, 31, 23, 59)), 30);
      expect(july.bucketIndex(DateTime(2026, 8, 1)), -1);

      final feb = DashWindow.of(DashRange.month, DateTime(2026, 2, 10));
      expect(feb.bucketStarts, hasLength(28)); // 2026: not a leap year

      final dec = DashWindow.of(DashRange.month, DateTime(2026, 12, 31));
      expect(dec.end, DateTime(2027)); // year rollover
      expect(dec.bucketStarts, hasLength(31));
    });
  });

  group('computeDashData', () {
    test('sessions bucket by endTime — a midnight-crosser lands on the day '
        'it finished', () {
      final w = DashWindow.of(DashRange.week, now);
      final data = computeDashData(
        window: w,
        sessions: [
          // Started Tuesday 23:30, ended Wednesday 00:20 → Wednesday (2).
          session(
            id: 's1',
            status: SessionStatus.completed,
            start: DateTime(2026, 7, 7, 23, 30),
            end: DateTime(2026, 7, 8, 0, 20),
            actualMin: 50,
          ),
        ],
        attempts: const [],
        recoveryEvents: const [],
      );
      expect(data.buckets[1].completed, 0);
      expect(data.buckets[2].completed, 1);
      expect(data.buckets[2].focusMinutes, 50);
    });

    test('statuses split into completed vs ended-early; live and '
        'out-of-window rows are ignored', () {
      final w = DashWindow.of(DashRange.week, now);
      final data = computeDashData(
        window: w,
        sessions: [
          session(
            id: 's1',
            status: SessionStatus.completed,
            start: DateTime(2026, 7, 10, 8),
            end: DateTime(2026, 7, 10, 8, 25),
            actualMin: 25,
          ),
          session(
            id: 's2',
            status: SessionStatus.aborted,
            start: DateTime(2026, 7, 10, 12),
            end: DateTime(2026, 7, 10, 12, 10),
            actualMin: 10,
          ),
          session(
            id: 's3',
            status: SessionStatus.failedPermissions,
            start: DateTime(2026, 7, 9, 12),
            end: DateTime(2026, 7, 9, 12, 5),
            actualMin: 5,
          ),
          // Still running: no endTime, nothing terminal to count.
          session(
            id: 's4',
            status: SessionStatus.active,
            start: DateTime(2026, 7, 10, 14),
          ),
          // Ended before the window (over-fetched padding row).
          session(
            id: 's5',
            status: SessionStatus.completed,
            start: DateTime(2026, 7, 5, 10),
            end: DateTime(2026, 7, 5, 10, 30),
            actualMin: 30,
          ),
        ],
        attempts: const [],
        recoveryEvents: const [],
      );
      expect(data.totalCompleted, 1);
      expect(data.totalEndedEarly, 2); // aborted + failedPermissions
      expect(data.totalFocusMinutes, 40); // 25 + 10 + 5, s5 excluded
      final friday = data.buckets[4];
      expect(friday.completed, 1);
      expect(friday.endedEarly, 1);
    });

    test('attempts bucket by ts; recoveries count resumed/exited in-window '
        'only; in-progress events are not samples', () {
      final w = DashWindow.of(DashRange.day, now);
      final data = computeDashData(
        window: w,
        sessions: const [],
        attempts: [
          attempt(1, DateTime(2026, 7, 10, 9, 10)),
          attempt(2, DateTime(2026, 7, 10, 9, 40)),
          attempt(3, DateTime(2026, 7, 10, 21, 5)),
          attempt(4, DateTime(2026, 7, 9, 9, 10)), // yesterday → ignored
        ],
        recoveryEvents: [
          recovery(1, DateTime(2026, 7, 10, 9, 15), RecoveryResult.resumed),
          recovery(2, DateTime(2026, 7, 10, 9, 45), RecoveryResult.exited),
          recovery(3, DateTime(2026, 7, 10, 10), null), // in progress
          recovery(4, DateTime(2026, 7, 9, 9), RecoveryResult.resumed), // out
        ],
      );
      expect(data.buckets[9].distractions, 2);
      expect(data.buckets[21].distractions, 1);
      expect(data.totalDistractions, 3);
      expect(data.recoveriesResumed, 1);
      expect(data.recoveriesExited, 1);
      expect(data.resumeRate, 0.5);
    });

    test('empty window → isEmpty and resumeRate null (no fake 0 %)', () {
      final data = computeDashData(
        window: DashWindow.of(DashRange.month, now),
        sessions: const [],
        attempts: const [],
        recoveryEvents: const [],
      );
      expect(data.isEmpty, isTrue);
      expect(data.resumeRate, isNull);
      expect(data.buckets, hasLength(31));
    });
  });
}
