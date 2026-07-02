import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'recovery_illustration.dart';

/// Shared body for the two 45-second reset modules (Stand & stretch, Water
/// break, SCREENS §5.3/§5.4): an illustration, a gentle Sage countdown ring, a
/// guidance prompt, and an early-complete button ("honors agency").
///
/// The [duration] elapses to [onFinished] naturally, or the user completes
/// early via the button. A [totalSeconds]-based label keeps TalkBack honest.
class TimedResetBody extends StatefulWidget {
  const TimedResetBody({
    super.key,
    required this.illustrationAsset,
    required this.prompt,
    required this.earlyCompleteLabel,
    required this.onFinished,
    this.duration = const Duration(seconds: 45),
    this.tick = const Duration(seconds: 1),
  });

  final String illustrationAsset;
  final String prompt;
  final String earlyCompleteLabel;

  /// Called once when the timer reaches zero OR the user completes early.
  final VoidCallback onFinished;
  final Duration duration;
  final Duration tick;

  @override
  State<TimedResetBody> createState() => _TimedResetBodyState();
}

class _TimedResetBodyState extends State<TimedResetBody> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _finished = false;

  int get _totalSeconds => widget.duration.inSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;
    _timer = Timer.periodic(widget.tick, (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds -= widget.tick.inSeconds);
      if (_remainingSeconds <= 0) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    final shown = _remainingSeconds.clamp(0, _totalSeconds);
    final progress = _totalSeconds == 0 ? 1.0 : shown / _totalSeconds;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RecoveryIllustration(asset: widget.illustrationAsset),
        const SizedBox(height: FokusSpacing.lg),
        // Sage countdown ring with the seconds label at its center.
        Semantics(
          label: l10n.recoverySecondsLabel(shown),
          child: SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: fokus.ringTrack,
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.secondary),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    '$shown',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FokusSpacing.lg),
        Text(
          widget.prompt,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FokusSpacing.lg),
        TextButton(
          onPressed: _finish,
          style: TextButton.styleFrom(
            minimumSize: const Size(
              FokusSpacing.minTouchTarget,
              FokusSpacing.minTouchTarget,
            ),
          ),
          child: Text(widget.earlyCompleteLabel),
        ),
      ],
    );
  }
}
