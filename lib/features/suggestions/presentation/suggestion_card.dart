import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/suggestion_service.dart';

/// Inline dismissible suggestion card on home (F-17, SCREENS §1 item 7).
/// Renders nothing when opted out, no rule fired, or already dismissed today.
/// Every card carries its "why" (spec §3.10 — explainable, never spooky).
class SuggestionCard extends ConsumerWidget {
  const SuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suggestion = ref.watch(todaysSuggestionProvider).value;
    if (suggestion == null) return const SizedBox.shrink();

    final title = switch (suggestion.type) {
      'distraction_window' => l10n.sugWindowTitle(
          '${suggestion.hour!.toString().padLeft(2, '0')}:00',
        ),
      'optimal_length' => l10n.sugLengthTitle(suggestion.minutes!),
      _ => null,
    };
    final body = switch (suggestion.type) {
      'distraction_window' => l10n.sugWindowBody,
      'optimal_length' => l10n.sugLengthBody,
      _ => null,
    };
    if (title == null || body == null) return const SizedBox.shrink();

    Future<void> resolve({required bool actedOn}) async {
      await ref
          .read(suggestionServiceProvider)
          .dismiss(suggestion.id, actedOn: actedOn);
      ref.invalidate(todaysSuggestionProvider);
    }

    return Card(
      color: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.lg),
      ),
      margin: const EdgeInsets.only(top: FokusSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 20,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: FokusSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.sugDismiss,
                  onPressed: () => resolve(actedOn: false),
                ),
              ],
            ),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: FokusSpacing.xxs),
            Text(
              l10n.sugWhy,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await resolve(actedOn: true);
                  if (context.mounted) context.go(AppRoutes.newSession);
                },
                child: Text(l10n.sugAct),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
