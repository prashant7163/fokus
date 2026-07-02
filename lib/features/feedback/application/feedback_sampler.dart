import '../../../core/constants.dart';

/// Pure 1-in-3 sampling (fokus-specs §3.9, CONTRACTS §4): the prompt shows
/// on the 1st, 4th, 7th… completed session. Derived from the completed count
/// so it is deterministic and replay-safe — no stored counter to drift.
abstract final class FeedbackSampler {
  static bool shouldAsk(int completedSessionCount) =>
      completedSessionCount > 0 &&
      completedSessionCount % FokusConstants.feedbackSamplingOneIn == 1;
}
