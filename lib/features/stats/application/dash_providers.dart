import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/data/database.dart';
import '../../../core/data/providers.dart';
import '../../../core/session/session_controller.dart' show clockProvider;
import 'dash_calculator.dart';
import 'focus_score.dart';

/// Sessions are attributed to buckets by endTime, but `sessionsBetween`
/// filters by startTime — pad the query start by the longest possible
/// session so a midnight-crosser that *ends* inside the window is fetched.
Duration get _sessionPadding =>
    const Duration(minutes: FokusConstants.customDurationMaxMin);

Future<List<DistractionAttempt>> _attemptsFor(
  Ref ref,
  List<FocusSession> sessions,
) async {
  final distractions = ref.watch(distractionRepositoryProvider);
  final attempts = <DistractionAttempt>[];
  for (final s in sessions) {
    attempts.addAll(await distractions.attemptsForSession(s.id));
  }
  return attempts;
}

/// Bucketed dashboard data for one segmented range (F-14, spec §3.6).
final dashDataProvider = FutureProvider.autoDispose
    .family<DashData, DashRange>((ref, range) async {
  final window = DashWindow.of(range, ref.watch(clockProvider)());
  final sessions = await ref
      .watch(sessionRepositoryProvider)
      .sessionsBetween(window.start.subtract(_sessionPadding), window.end);
  return computeDashData(
    window: window,
    sessions: sessions,
    attempts: await _attemptsFor(ref, sessions),
    recoveryEvents: await ref.watch(recoveryRepositoryProvider).completedEvents(),
  );
});

/// Weekly focus score vs the personal 4-week baseline (spec §3.6, v1/beta).
/// Null = no terminal session this week yet (UI shows the empty state).
final focusScoreProvider =
    FutureProvider.autoDispose<FocusScoreResult?>((ref) async {
  final week = DashWindow.of(DashRange.week, ref.watch(clockProvider)());
  final baselineStart = DateTime(
    week.start.year,
    week.start.month,
    week.start.day - 28,
  );

  final sessions = await ref.watch(sessionRepositoryProvider).sessionsBetween(
        baselineStart.subtract(_sessionPadding),
        week.end,
      );

  var completed = 0;
  var endedEarly = 0;
  var weekMinutes = 0;
  var baselineMinutes = 0;
  for (final s in sessions) {
    final end = s.endTime;
    if (end == null) continue;
    if (week.contains(end)) {
      weekMinutes += s.actualMin ?? 0;
      switch (s.status) {
        case SessionStatus.completed:
          completed++;
        case SessionStatus.aborted:
        case SessionStatus.failedPermissions:
          endedEarly++;
        default:
          break;
      }
    } else if (!end.isBefore(baselineStart) && end.isBefore(week.start)) {
      baselineMinutes += s.actualMin ?? 0;
    }
  }

  var resumed = 0;
  var exited = 0;
  final events = await ref.watch(recoveryRepositoryProvider).completedEvents();
  for (final e in events) {
    if (!week.contains(e.startedAt)) continue;
    if (e.result == RecoveryResult.resumed) resumed++;
    if (e.result == RecoveryResult.exited) exited++;
  }

  return computeFocusScore(
    completed: completed,
    endedEarly: endedEarly,
    focusMinutes: weekMinutes,
    baselineWeeklyMinutes: baselineMinutes > 0 ? baselineMinutes / 4 : null,
    recoveriesResumed: resumed,
    recoveriesExited: exited,
  );
});
