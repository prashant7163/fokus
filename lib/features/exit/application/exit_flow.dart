import '../../../core/data/enums.dart';

/// What the exit flow does after a reason is picked (fokus-specs §3.4,
/// SCREENS §6). Pure decision table — navigation and session calls live in
/// the screen; this is the part that must never drift from the spec.
enum ExitOutcome {
  /// finishedTask → session completes and counts as done (celebratory path).
  completeAsFinished,

  /// emergency → immediate exit, no lecture, no penalty, never gated
  /// (fokus-specs §2.3 — strict mode must not add a single step here).
  exitNow,

  /// stuck → recovery hub (the user picks what helps).
  recoveryHub,

  /// tired → recovery with Breathe preselected (SCREENS §6).
  recoveryBreathe,

  /// needApp, non-strict → single-app picker for a 5-minute pass; the
  /// session timer keeps running (never a pause — D-011).
  pickPassApp,

  /// needApp, strict → denied kindly, recovery offered instead. Blocking
  /// the needApp path is F-08's done-criterion for strict mode.
  strictDenied,
}

abstract final class ExitFlow {
  static ExitOutcome outcomeFor(
    ExitReason reason, {
    required bool strictMode,
  }) =>
      switch (reason) {
        ExitReason.finishedTask => ExitOutcome.completeAsFinished,
        ExitReason.emergency => ExitOutcome.exitNow,
        ExitReason.stuck => ExitOutcome.recoveryHub,
        ExitReason.tired => ExitOutcome.recoveryBreathe,
        ExitReason.needApp =>
          strictMode ? ExitOutcome.strictDenied : ExitOutcome.pickPassApp,
      };
}
