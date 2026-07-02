import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/blocking/blocking_adapter.dart';
import '../../../../core/blocking/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Permission checklist (F-10, SCREENS §8.3): one card per permission with a
/// plain-language "why" (benefit, not demand), a status badge, and a set-up
/// deep link. Continue is ALWAYS enabled — partial setup lands in limited
/// mode with honest labels; "2 of 4 set up" is informational, never a nag.
///
/// Reached only AFTER disclosure consent (Play policy: the accessibility
/// settings redirect lives here, behind the consent gate).
class PermissionsStep extends ConsumerStatefulWidget {
  const PermissionsStep({
    super.key,
    required this.onContinue,
    required this.onLater,
  });

  final VoidCallback onContinue;
  final VoidCallback onLater;

  @override
  ConsumerState<PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends ConsumerState<PermissionsStep>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a settings screen → re-read statuses live (§8.3).
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(permissionStatusProvider).value;

    final cards = <(PermissionKind, String, String)>[
      (PermissionKind.accessibility, l10n.permAccessibilityName,
          l10n.permAccessibilityWhy),
      (PermissionKind.usageStats, l10n.permUsageName, l10n.permUsageWhy),
      (PermissionKind.notifications, l10n.permNotificationsName,
          l10n.permNotificationsWhy),
      (PermissionKind.batteryExemption, l10n.permBatteryName,
          l10n.permBatteryWhy),
    ];
    final grantedCount = status == null
        ? 0
        : cards.where((c) => status.isGranted(c.$1)).length;

    return Padding(
      padding: const EdgeInsets.all(FokusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.onbPermsTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: FokusSpacing.xxs),
          Text(
            l10n.onbPermsSubtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: FokusSpacing.xs),
          Text(
            l10n.onbPermsProgress(grantedCount, cards.length),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: FokusSpacing.md),
          Expanded(
            child: ListView(
              children: [
                for (final (kind, name, why) in cards)
                  _PermissionCard(
                    kind: kind,
                    name: name,
                    why: why,
                    granted: status?.isGranted(kind) ?? false,
                  ),
              ],
            ),
          ),
          Text(
            l10n.onbPermsFinishAnytime,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FokusSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            ),
            onPressed: widget.onContinue,
            child: Text(l10n.onbContinue),
          ),
          const SizedBox(height: FokusSpacing.xs),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            ),
            onPressed: widget.onLater,
            child: Text(l10n.onbLater),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard({
    required this.kind,
    required this.name,
    required this.why,
    required this.granted,
  });

  final PermissionKind kind;
  final String name;
  final String why;
  final bool granted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final badgeText = granted ? l10n.permStatusActive : l10n.permStatusNeeded;

    return Semantics(
      label: '$name: $badgeText. $why',
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FokusRadius.md),
        ),
        margin: const EdgeInsets.only(bottom: FokusSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(FokusSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: theme.textTheme.titleMedium),
                        const SizedBox(width: FokusSpacing.xs),
                        _Badge(granted: granted, text: badgeText),
                      ],
                    ),
                    const SizedBox(height: FokusSpacing.xxs),
                    Text(
                      why,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!granted)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      FokusSpacing.minTouchTarget,
                      FokusSpacing.minTouchTarget,
                    ),
                  ),
                  onPressed: () => ref
                      .read(blockingAdapterProvider)
                      .requestPermission(kind),
                  child: Text(l10n.permSetUp),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.granted, required this.text});

  final bool granted;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FokusSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: granted ? scheme.secondaryContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(FokusRadius.full),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: granted
                  ? scheme.onSecondaryContainer
                  : scheme.onTertiaryContainer,
            ),
      ),
    );
  }
}
