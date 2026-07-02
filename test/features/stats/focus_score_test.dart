import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/features/stats/application/focus_score.dart';

/// F-14 focus score v1 (fokus-specs §3.6): 50 % completion + 30 % volume vs
/// 4-week baseline + 20 % recovery resume-rate, with weight redistribution
/// for unavailable components.
void main() {
  group('computeFocusScore', () {
    test('all three components available → spec weights apply', () {
      final s = computeFocusScore(
        completed: 8,
        endedEarly: 2,
        focusMinutes: 300,
        baselineWeeklyMinutes: 300,
        recoveriesResumed: 3,
        recoveriesExited: 1,
      )!;
      expect(s.completionRate, 0.8);
      expect(s.volumeVsBaseline, 1.0);
      expect(s.resumeRate, 0.75);
      // 100 * (0.5*0.8 + 0.3*1.0 + 0.2*0.75) = 85
      expect(s.score, 85);
    });

    test('zero-session week → no score (null, not a hollow 0)', () {
      expect(
        computeFocusScore(
          completed: 0,
          endedEarly: 0,
          focusMinutes: 0,
          baselineWeeklyMinutes: 120,
          recoveriesResumed: 2,
          recoveriesExited: 0,
        ),
        isNull,
      );
    });

    test('new user: no baseline → volume weight redistributed', () {
      final s = computeFocusScore(
        completed: 8,
        endedEarly: 2,
        focusMinutes: 200,
        baselineWeeklyMinutes: null,
        recoveriesResumed: 3,
        recoveriesExited: 1,
      )!;
      expect(s.volumeVsBaseline, isNull);
      // 100 * (0.5*0.8 + 0.2*0.75) / 0.7 ≈ 78.6 → 79
      expect(s.score, 79);
    });

    test('zero baseline behaves like no baseline', () {
      final withNull = computeFocusScore(
        completed: 3,
        endedEarly: 1,
        focusMinutes: 90,
        baselineWeeklyMinutes: null,
        recoveriesResumed: 1,
        recoveriesExited: 1,
      )!;
      final withZero = computeFocusScore(
        completed: 3,
        endedEarly: 1,
        focusMinutes: 90,
        baselineWeeklyMinutes: 0,
        recoveriesResumed: 1,
        recoveriesExited: 1,
      )!;
      expect(withZero.score, withNull.score);
      expect(withZero.volumeVsBaseline, isNull);
    });

    test('resume-rate with <1 sample → recovery weight redistributed', () {
      final s = computeFocusScore(
        completed: 8,
        endedEarly: 2,
        focusMinutes: 300,
        baselineWeeklyMinutes: 300,
        recoveriesResumed: 0,
        recoveriesExited: 0,
      )!;
      expect(s.resumeRate, isNull);
      // 100 * (0.5*0.8 + 0.3*1.0) / 0.8 = 87.5 → 88
      expect(s.score, 88);
    });

    test('first week ever: completion rate alone carries the score', () {
      final s = computeFocusScore(
        completed: 4,
        endedEarly: 1,
        focusMinutes: 100,
        baselineWeeklyMinutes: null,
        recoveriesResumed: 0,
        recoveriesExited: 0,
      )!;
      expect(s.volumeVsBaseline, isNull);
      expect(s.resumeRate, isNull);
      expect(s.score, 80); // 4/5 completion, full weight
    });

    test('volume vs baseline is capped at 1 (no >100 % credit)', () {
      final s = computeFocusScore(
        completed: 1,
        endedEarly: 0,
        focusMinutes: 600,
        baselineWeeklyMinutes: 100,
        recoveriesResumed: 0,
        recoveriesExited: 0,
      )!;
      expect(s.volumeVsBaseline, 1.0);
      expect(s.score, 100);
    });

    test('perfect week → 100', () {
      expect(
        computeFocusScore(
          completed: 5,
          endedEarly: 0,
          focusMinutes: 250,
          baselineWeeklyMinutes: 200,
          recoveriesResumed: 4,
          recoveriesExited: 0,
        )!
            .score,
        100,
      );
    });

    test('everything ended early, nothing else scoreable → 0', () {
      expect(
        computeFocusScore(
          completed: 0,
          endedEarly: 3,
          focusMinutes: 10,
          baselineWeeklyMinutes: null,
          recoveriesResumed: 0,
          recoveriesExited: 0,
        )!
            .score,
        0,
      );
    });
  });
}
