import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/achievement_engine.dart';
import 'widgets/achievement_badge.dart';

/// code → unlockedAt for everything unlocked so far.
final unlockedAchievementsProvider =
    FutureProvider.autoDispose<Map<String, DateTime>>((ref) async {
  final rows = await ref.watch(achievementRepositoryProvider).getAll();
  return {for (final row in rows) row.code: row.unlockedAt};
});

/// Badge gallery (F-15, fokus-specs §3.8): all eight achievements with
/// locked/unlocked state and unlock dates. Reached from the stats app bar.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unlocked = ref.watch(unlockedAchievementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: unlocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (byCode) => ListView.separated(
          padding: const EdgeInsets.all(FokusSpacing.screenPadding),
          itemCount: AchievementCode.values.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: FokusSpacing.sm),
          itemBuilder: (context, index) {
            final code = AchievementCode.values[index];
            return _AchievementTile(
              code: code,
              unlockedAt: byCode[code.name],
            );
          },
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.code, required this.unlockedAt});

  final AchievementCode code;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    final unlocked = unlockedAt != null;
    final status = unlocked
        ? l10n.achUnlockedOn(
            MaterialLocalizations.of(context).formatShortDate(unlockedAt!))
        : l10n.achLocked;

    return Semantics(
      label: '${code.nameOf(l10n)}. ${code.descriptionOf(l10n)}. $status',
      container: true,
      child: ExcludeSemantics(
        child: Card(
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FokusRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(FokusSpacing.md),
            child: Row(
              children: [
                AchievementBadge(code: code, unlocked: unlocked),
                const SizedBox(width: FokusSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code.nameOf(l10n),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: unlocked
                              ? null
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code.descriptionOf(l10n),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: FokusSpacing.xs),
                      Text(
                        status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: unlocked
                              ? fokus.streakSignal
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
