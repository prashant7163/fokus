import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../achievements/presentation/widgets/session_achievements_banner.dart';
import '../../feedback/presentation/feedback_row.dart';

/// Session Complete (F-09, SCREENS §7): full-screen celebration — warm,
/// earned, never infantilizing. Reached right after a session lands on
/// `completed` (timer end via the active-session screen once F-11 wires it;
/// finishedTask and lock-break redemption via the exit flow now).
///
/// Aborted/emergency sessions never see this screen (SCREENS §7) — they go
/// straight home with a neutral toast.
///
/// Micro-feedback (step 5, 1-in-3 sampling) arrives with F-16 — slot noted.
class SessionCompleteScreen extends ConsumerStatefulWidget {
  const SessionCompleteScreen({super.key});

  @override
  ConsumerState<SessionCompleteScreen> createState() =>
      _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends ConsumerState<SessionCompleteScreen> {
  int? _distractions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = ref.read(sessionControllerProvider);
      if (session.status != SessionStatus.completed) {
        // Direct navigation without a fresh completion — nothing to show.
        if (mounted) context.go(AppRoutes.home);
        return;
      }
      final id = session.sessionId;
      if (id == null) return;
      final attempts =
          await ref.read(distractionRepositoryProvider).attemptsForSession(id);
      if (mounted) setState(() => _distractions = attempts.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    final session = ref.watch(sessionControllerProvider);

    if (session.status != SessionStatus.completed) {
      return const Scaffold(body: SizedBox.shrink()); // redirecting home.
    }

    final minutes = session.plannedMin ?? 0;
    final actual = _actualMinutes(session);
    final headline = switch (session.completionReason) {
      CompletionReason.lockBreak => l10n.completeHeadlineLockBreak,
      CompletionReason.finishedTask => l10n.completeHeadlineFinished,
      _ => l10n.completeHeadline(minutes),
    };
    final outcome = session.streakOutcome;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: fokus.calmWash),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FokusSpacing.lg),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: FokusSpacing.xl),
                        _CelebrationRing(reduceMotion: reduceMotion),
                const SizedBox(height: FokusSpacing.xl),
                Text(
                  headline,
                  style: theme.textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FokusSpacing.lg),
                Card(
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FokusRadius.lg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(FokusSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.completeFocusDelta(actual),
                          style: theme.textTheme.titleMedium,
                        ),
                        if (_distractions != null) ...[
                          const SizedBox(height: FokusSpacing.xs),
                          Text(
                            l10n.completeDistractions(_distractions!),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        if (session.taskAnchor?.isNotEmpty ?? false) ...[
                          const SizedBox(height: FokusSpacing.xs),
                          Text(
                            l10n.completeAnchorEcho(session.taskAnchor!),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (outcome != null && outcome.incremented) ...[
                  const SizedBox(height: FokusSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: fokus.streakSignal),
                      const SizedBox(width: FokusSpacing.xs),
                      Text(
                        l10n.completeStreak(outcome.streakDays),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
                if ((outcome?.tokensEarned ?? 0) > 0) ...[
                  const SizedBox(height: FokusSpacing.xs),
                  Text(
                    l10n.completeTokenEarned(outcome!.tokensEarned),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: fokus.streakSignal),
                    textAlign: TextAlign.center,
                  ),
                ],
                // F-15: evaluates achievements post-frame; celebrates only
                // what THIS completion newly unlocked (unlock/celebrate once).
                const SessionAchievementsBanner(),
                        // F-16: sampled 1-in-3, skippable, 😔 captures a
                        // reason.
                        const FeedbackRow(),
                        const SizedBox(height: FokusSpacing.lg),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(FokusSpacing.minTouchTarget),
                  ),
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text(l10n.completeDone),
                ),
                const SizedBox(height: FokusSpacing.xs),
                // TODO(F-11): one-tap repeat of the last configuration.
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(FokusSpacing.minTouchTarget),
                  ),
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text(l10n.completeStartAnother),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _actualMinutes(SessionState session) {
    // actualMin is persisted, not carried in state — and state.endTime is the
    // wall-clock ANCHOR (start + planned), not the completion moment, so an
    // early finish must derive from now (found in the F-11 emulator pass:
    // a 4-minute finishTask celebrated "+30 focus minutes").
    final start = session.startTime;
    final planned = session.plannedMin ?? 0;
    if (start == null) return planned;
    final min = DateTime.now().difference(start).inMinutes;
    return min < 0 ? 0 : (min > planned ? planned : min);
  }
}

/// The progress ring closing once with a gentle amber pulse (`celebrate`
/// motion) — a check-free, trophy-free earned moment. Reduced motion renders
/// the closed ring statically.
class _CelebrationRing extends StatefulWidget {
  const _CelebrationRing({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_CelebrationRing> createState() => _CelebrationRingState();
}

class _CelebrationRingState extends State<_CelebrationRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => SizedBox(
        width: 96,
        height: 96,
        child: CircularProgressIndicator(
          value: Curves.easeOutCubic.transform(_controller.value),
          strokeWidth: 6,
          color: theme.colorScheme.primary,
          backgroundColor:
              theme.extension<FokusColors>()!.ringTrack,
        ),
      ),
    );
  }
}
