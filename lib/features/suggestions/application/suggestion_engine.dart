import '../../../core/data/enums.dart';

/// A concrete, explainable suggestion (fokus-specs §3.10). [hour]/[minutes]
/// carry the rule-specific payload.
class Suggestion {
  const Suggestion.distractionWindow(this.hour)
      : type = 'distraction_window',
        minutes = null;
  const Suggestion.optimalLength(this.minutes)
      : type = 'optimal_length',
        hour = null;

  final String type;
  final int? hour;
  final int? minutes;
}

/// Minimal session facts the engine needs — fixture-friendly.
class SessionFact {
  const SessionFact({
    required this.plannedMin,
    required this.completed,
    required this.startTime,
  });

  final int plannedMin;
  final bool completed;
  final DateTime startTime;
}

/// Pure rule evaluation over local history (fokus-specs §3.10). No IO, no
/// clock — callers pass `now`. All thresholds live here, documented, so the
/// "beta" formula is one file to revisit with data.
abstract final class SuggestionEngine {
  /// History gate: rules only run with ≥ 14 days between the oldest session
  /// and now (spec: "rule-based on ≥ 14 days of local data").
  static bool hasEnoughHistory(DateTime? oldestSession, DateTime now) =>
      oldestSession != null && now.difference(oldestSession).inDays >= 14;

  /// Distraction window: an hour-of-day qualifies when attempts occurred in
  /// it on ≥ 4 distinct days of the last 7. Returns the qualifying hour with
  /// the most attempt-days (earliest wins ties), else null.
  static int? distractionWindow(List<DateTime> attempts, DateTime now) {
    final cutoff = now.subtract(const Duration(days: 7));
    final daysPerHour = <int, Set<int>>{};
    for (final ts in attempts) {
      if (ts.isBefore(cutoff) || ts.isAfter(now)) continue;
      daysPerHour
          .putIfAbsent(ts.hour, () => <int>{})
          .add(DateTime(ts.year, ts.month, ts.day).millisecondsSinceEpoch);
    }
    int? best;
    var bestDays = 0;
    for (var hour = 0; hour < 24; hour++) {
      final days = daysPerHour[hour]?.length ?? 0;
      if (days >= 4 && days > bestDays) {
        best = hour;
        bestDays = days;
      }
    }
    return best;
  }

  /// Minimum samples per bucket for the optimal-length rule — the spec's v1
  /// formula leaves this open; 3 keeps noise out without demanding weeks.
  static const minLengthSamples = 3;

  /// Optimal length: the shortest duration whose completion rate beats the
  /// pooled rate of all LONGER sessions by ≥ 25 percentage points (both
  /// sides need [minLengthSamples]). Null when no duration qualifies.
  static int? optimalLength(List<SessionFact> sessions) {
    final byDuration = <int, List<SessionFact>>{};
    for (final s in sessions) {
      byDuration.putIfAbsent(s.plannedMin, () => []).add(s);
    }
    final durations = byDuration.keys.toList()..sort();
    for (final duration in durations) {
      final own = byDuration[duration]!;
      if (own.length < minLengthSamples) continue;
      final longer = [
        for (final s in sessions)
          if (s.plannedMin > duration) s,
      ];
      if (longer.length < minLengthSamples) continue;
      final ownRate = own.where((s) => s.completed).length / own.length;
      final longerRate =
          longer.where((s) => s.completed).length / longer.length;
      if (ownRate - longerRate >= 0.25) return duration;
    }
    return null;
  }

  /// Recovery ordering: modules with ≥ 5 closed samples re-rank among their
  /// own slots by resume rate (desc); under-sampled modules keep their
  /// DEFAULT positions — a menu should never feel random (spec §3.10:
  /// "min 5 samples per module").
  static List<RecoveryType> recoveryOrder(
    Map<RecoveryType, ({int resumed, int total})> stats,
  ) {
    const defaultOrder = RecoveryType.values;
    final sampled = <RecoveryType>[
      for (final t in defaultOrder)
        if ((stats[t]?.total ?? 0) >= 5) t,
    ];
    if (sampled.length < 2) return List.of(defaultOrder);
    final ranked = List.of(sampled)
      ..sort((a, b) {
        double rate(RecoveryType t) =>
            stats[t]!.resumed / stats[t]!.total;
        return rate(b).compareTo(rate(a));
      });
    // Re-place ranked modules into the sampled slots, preserving the
    // positions of under-sampled ones.
    final result = List.of(defaultOrder);
    var rankIndex = 0;
    for (var i = 0; i < result.length; i++) {
      if (sampled.contains(result[i])) {
        result[i] = ranked[rankIndex++];
      }
    }
    return result;
  }
}
