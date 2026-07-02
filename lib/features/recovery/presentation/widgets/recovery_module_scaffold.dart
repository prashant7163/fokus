import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Shared chrome for every recovery module (SCREENS §5): the `calmWash` field,
/// a close/handle at top (dismiss = abandon), the module body, then the
/// **"Ready to continue?"** footer. The softest, most generously-spaced room in
/// the product.
///
/// [showFooter] hides the Resume/End footer for the Shrink module, which owns
/// its own two CTAs. [onClose] fires when the close handle is tapped.
class RecoveryModuleScaffold extends StatelessWidget {
  const RecoveryModuleScaffold({
    super.key,
    required this.child,
    required this.onClose,
    this.onResume,
    this.onEnd,
    this.showFooter = true,
  });

  final Widget child;
  final VoidCallback onClose;
  final VoidCallback? onResume;
  final VoidCallback? onEnd;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: fokus.calmWash),
        child: SafeArea(
          child: Column(
            children: [
              // Close handle (dismiss = abandon).
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(FokusSpacing.xs),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.recoveryClose,
                    onPressed: onClose,
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: FokusSpacing.minTouchTarget,
                      minHeight: FokusSpacing.minTouchTarget,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FokusSpacing.lg,
                    ),
                    child: child,
                  ),
                ),
              ),
              if (showFooter)
                _ReadyFooter(onResume: onResume, onEnd: onEnd),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Ready to continue?" footer: Resume (primary) + End (de-emphasized).
/// No countdown — the choice is never pressured (SCREENS §5).
class _ReadyFooter extends StatelessWidget {
  const _ReadyFooter({this.onResume, this.onEnd});

  final VoidCallback? onResume;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FokusSpacing.lg,
        FokusSpacing.md,
        FokusSpacing.lg,
        FokusSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.recoveryReadyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FokusSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onResume,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
              child: Text(l10n.recoveryResume),
            ),
          ),
          const SizedBox(height: FokusSpacing.xs),
          TextButton(
            onPressed: onEnd,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: Text(l10n.recoveryEnd),
          ),
        ],
      ),
    );
  }
}
