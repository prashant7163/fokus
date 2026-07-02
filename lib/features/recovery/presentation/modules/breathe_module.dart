import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Breathe module body (SCREENS §5.1): the breathing circle — 4 s inhale
/// (expand) / 4 s hold / 4 s exhale (contract), the signature `breath`
/// (4000 ms easeInOutSine) motion. Minimum 2 cycles, then it settles and
/// [onCompleted] fires (the footer's "Ready to continue?" takes over).
///
/// Phase words cross-fade in the center; cycle dots fill below. Reduced motion
/// (MediaQuery.disableAnimations) swaps the scale for an opacity pulse and
/// shows a per-phase progress bar — the breath guidance is never removed.
class BreatheModule extends StatefulWidget {
  const BreatheModule({
    super.key,
    required this.onCompleted,
    this.minCycles = 2,
    this.phaseDuration = FokusMotion.breath,
  });

  /// Fired once the minimum cycles complete (circle settled).
  final VoidCallback onCompleted;
  final int minCycles;

  /// One phase (inhale, hold, or exhale). 4 s per the design system.
  final Duration phaseDuration;

  @override
  State<BreatheModule> createState() => _BreatheModuleState();
}

enum _Phase { inhale, hold, exhale }

class _BreatheModuleState extends State<BreatheModule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  _Phase _phase = _Phase.inhale;
  int _completedCycles = 0;
  bool _done = false;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.phaseDuration,
      value: 0, // contracted at rest.
    );
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: FokusMotion.curveBreath),
    );
    // Start on the next frame so MediaQuery (reduced-motion) is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPhase());
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _reducedMotion =>
      mounted && MediaQuery.maybeDisableAnimationsOf(context) == true;

  void _runPhase() {
    if (!mounted || _done) return;
    switch (_phase) {
      case _Phase.inhale:
        if (_reducedMotion) {
          _controller.value = 1;
        } else {
          _controller.forward(from: 0);
        }
      case _Phase.hold:
        // Stay expanded.
        _controller.value = 1;
      case _Phase.exhale:
        if (_reducedMotion) {
          _controller.value = 0;
        } else {
          _controller.reverse(from: 1);
        }
    }
    _phaseTimer?.cancel();
    _phaseTimer = Timer(widget.phaseDuration, _advance);
  }

  void _advance() {
    if (!mounted || _done) return;
    switch (_phase) {
      case _Phase.inhale:
        setState(() => _phase = _Phase.hold);
      case _Phase.hold:
        setState(() => _phase = _Phase.exhale);
      case _Phase.exhale:
        final cycles = _completedCycles + 1;
        if (cycles >= widget.minCycles) {
          setState(() {
            _completedCycles = cycles;
            _done = true;
          });
          widget.onCompleted();
          return;
        }
        setState(() {
          _completedCycles = cycles;
          _phase = _Phase.inhale;
        });
    }
    _runPhase();
  }

  String _phaseWord(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.inhale:
        return l10n.recoveryBreatheInhale;
      case _Phase.hold:
        return l10n.recoveryBreatheHold;
      case _Phase.exhale:
        return l10n.recoveryBreatheExhale;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    final word = _phaseWord(l10n);
    final reduced = _reducedMotion;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live region announces each phase for TalkBack (whole circle is
        // excluded from semantics — the word carries it).
        Semantics(
          liveRegion: true,
          label: word,
          child: const SizedBox.shrink(),
        ),
        SizedBox(
          width: 240,
          height: 240,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final circle = ExcludeSemantics(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: fokus.calmWash,
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: FokusMotion.calm,
                      child: Text(
                        word,
                        key: ValueKey(word),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                );
                if (reduced) {
                  // Opacity pulse instead of scale.
                  return Opacity(
                    opacity: 0.5 + 0.5 * _controller.value,
                    child: circle,
                  );
                }
                return Transform.scale(scale: _scale.value, child: circle);
              },
            ),
          ),
        ),
        if (reduced) ...[
          const SizedBox(height: FokusSpacing.md),
          // Per-phase progress bar so reduced-motion still guides the breath.
          SizedBox(
            width: 160,
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: _controller.value,
                backgroundColor: fokus.ringTrack,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: FokusSpacing.lg),
        // Cycle dots.
        Semantics(
          label: l10n.recoveryCycleLabel(
            (_completedCycles + (_done ? 0 : 1)).clamp(1, widget.minCycles),
            widget.minCycles,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.minCycles; i++)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: FokusSpacing.xxs),
                  child: ExcludeSemantics(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _completedCycles
                            ? theme.colorScheme.secondary
                            : fokus.ringTrack,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
