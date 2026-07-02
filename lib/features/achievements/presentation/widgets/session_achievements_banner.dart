import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/achievement_engine.dart';
import '../../application/achievements_service.dart';
import 'achievement_badge.dart';

/// Self-contained F-15 hook for the session-complete screen: evaluates the
/// achievement triggers after the first frame and, ONLY when this evaluation
/// unlocked something new, celebrates it inline with a badge row.
///
/// "Unlock once, celebrate once": the service returns codes solely from the
/// invocation that inserted the rows, so a re-visit (process death, replayed
/// completion, back-navigation) renders nothing.
class SessionAchievementsBanner extends ConsumerStatefulWidget {
  const SessionAchievementsBanner({super.key});

  @override
  ConsumerState<SessionAchievementsBanner> createState() =>
      _SessionAchievementsBannerState();
}

class _SessionAchievementsBannerState
    extends ConsumerState<SessionAchievementsBanner> {
  List<AchievementCode> _newlyUnlocked = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final unlocked =
          await ref.read(achievementsServiceProvider).evaluateAndUnlock();
      if (mounted && unlocked.isNotEmpty) {
        setState(() => _newlyUnlocked = unlocked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_newlyUnlocked.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Deliberately compact: the session-complete column is spacer-driven and
    // must never overflow on small screens even with several unlocks at once.
    return Padding(
      padding: const EdgeInsets.only(top: FokusSpacing.sm),
      child: _CelebrateIn(
        enabled: !reduceMotion,
        child: Column(
          children: [
            Text(
              l10n.achUnlockedHeadline(_newlyUnlocked.length),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: fokus.streakSignal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FokusSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final code in _newlyUnlocked) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: FokusSpacing.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AchievementBadge(code: code, size: 32),
                          const SizedBox(width: FokusSpacing.xs),
                          Text(
                            code.nameOf(l10n),
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gentle one-shot scale/fade-in — the `celebrate` treatment. Reduced motion
/// renders statically.
class _CelebrateIn extends StatefulWidget {
  const _CelebrateIn({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_CelebrateIn> createState() => _CelebrateInState();
}

class _CelebrateInState extends State<_CelebrateIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(scale: curve, child: widget.child),
    );
  }
}
