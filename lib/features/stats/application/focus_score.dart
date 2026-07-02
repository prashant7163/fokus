import 'dart:math' as math;

/// Focus score v1 (fokus-specs §3.6) — a weekly 0–100 score:
///
///   50 % completion rate
/// + 30 % focus volume vs the personal 4-week baseline
/// + 20 % recovery resume-rate
///
/// The formula is v1/beta — the UI labels it "beta". Pure function, no I/O.
///
/// Edge handling (new users, sparse weeks):
/// - Zero sessions this week → no score ([computeFocusScore] returns null);
///   the UI shows an empty state instead of a hollow 0.
/// - No baseline (no focus minutes in the prior 4 weeks) → the volume
///   component is *unavailable* and its weight is redistributed across the
///   available components (a first week is scored on what it can prove,
///   not punished for having no history).
/// - Fewer than 1 completed recovery sample → the recovery component is
///   unavailable; same redistribution.
class FocusScoreResult {
  const FocusScoreResult({
    required this.score,
    required this.completionRate,
    required this.volumeVsBaseline,
    required this.resumeRate,
  });

  /// 0–100, rounded.
  final int score;

  /// 0–1: completed / (completed + endedEarly).
  final double completionRate;

  /// 0–1 (capped at 1): weekly minutes / baseline weekly minutes.
  /// Null when there is no 4-week baseline yet.
  final double? volumeVsBaseline;

  /// 0–1: resumed / (resumed + exited). Null with zero recovery samples.
  final double? resumeRate;
}

/// Computes the weekly focus score. Returns null when the week has no
/// terminal sessions at all (nothing to score yet).
///
/// [completed] / [endedEarly] are this week's terminal session counts
/// (ended-early = aborted + failed-permissions: every session that did not
/// complete). [focusMinutes] is this week's summed actual minutes.
/// [baselineWeeklyMinutes] is the average weekly focus minutes over the
/// 4 weeks before this one — pass null (or ≤ 0) when there is no history.
/// [recoveriesResumed] / [recoveriesExited] are this week's completed
/// recovery events by outcome.
FocusScoreResult? computeFocusScore({
  required int completed,
  required int endedEarly,
  required int focusMinutes,
  required double? baselineWeeklyMinutes,
  required int recoveriesResumed,
  required int recoveriesExited,
}) {
  final sessions = completed + endedEarly;
  if (sessions <= 0) return null;

  final completionRate = completed / sessions;

  double? volume;
  if (baselineWeeklyMinutes != null && baselineWeeklyMinutes > 0) {
    volume = math.min(1.0, focusMinutes / baselineWeeklyMinutes);
  }

  double? resumeRate;
  final recoverySamples = recoveriesResumed + recoveriesExited;
  if (recoverySamples > 0) {
    resumeRate = recoveriesResumed / recoverySamples;
  }

  // Weighted mean over the *available* components (weights renormalized).
  var weightSum = 0.5;
  var valueSum = 0.5 * completionRate;
  if (volume != null) {
    weightSum += 0.3;
    valueSum += 0.3 * volume;
  }
  if (resumeRate != null) {
    weightSum += 0.2;
    valueSum += 0.2 * resumeRate;
  }

  return FocusScoreResult(
    score: (100 * valueSum / weightSum).round(),
    completionRate: completionRate,
    volumeVsBaseline: volume,
    resumeRate: resumeRate,
  );
}
