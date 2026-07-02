import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../widgets/recovery_illustration.dart';

/// Shrink session module body (SCREENS §5.5): "Finish small?" — reduce the
/// remaining time to 10 minutes and end on a win. Owns its own two CTAs
/// (Shrink / Keep full time) instead of the shared Resume/End footer.
///
/// Framed as kindness, never giving up. The parent screen wires [onShrink]
/// (applies via SessionController.shrinkTo, then resumes) and [onKeep] (resume
/// unchanged).
class ShrinkModule extends StatelessWidget {
  const ShrinkModule({
    super.key,
    required this.onShrink,
    required this.onKeep,
  });

  final VoidCallback onShrink;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: RecoveryIllustration(asset: 'recovery_shrink')),
        const SizedBox(height: FokusSpacing.lg),
        Text(
          l10n.recoveryShrinkPrompt,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FokusSpacing.sm),
        Text(
          l10n.recoveryShrinkBody,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FokusSpacing.xl),
        FilledButton(
          onPressed: onShrink,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
          ),
          child: Text(l10n.recoveryShrinkApply),
        ),
        const SizedBox(height: FokusSpacing.xs),
        TextButton(
          onPressed: onKeep,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
          child: Text(l10n.recoveryShrinkKeep),
        ),
      ],
    );
  }
}
