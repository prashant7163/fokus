import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/streaks/streak_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'dash_section.dart';

/// Today's four MVP stats (F-09, fokus-specs §3.6): focus minutes,
/// distractions blocked, most-intercepted app, current streak.
/// The day/week/month dashboard + focus score arrive with F-14.
final todayStatsProvider = FutureProvider.autoDispose<TodayStats>(
  (ref) => ref.watch(streakServiceProvider).todayStats(),
);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stats = ref.watch(todayStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        actions: [
          // F-15: badge-gallery entry point.
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: l10n.achievementsTitle,
            onPressed: () => context.push(AppRoutes.achievements),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (today) => ListView(
          padding: const EdgeInsets.all(FokusSpacing.screenPadding),
          children: [
            Text(l10n.statsTodayTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: FokusSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: FokusSpacing.sm,
              crossAxisSpacing: FokusSpacing.sm,
              childAspectRatio: 1.35,
              children: [
                _StatTile(
                  icon: Icons.timer_outlined,
                  label: l10n.statsFocusMinutes,
                  value: l10n.statsMinutesValue(today.focusMinutes),
                ),
                _StatTile(
                  icon: Icons.shield_outlined,
                  label: l10n.statsDistractionsBlocked,
                  value: '${today.distractionsBlocked}',
                ),
                _StatTile(
                  icon: Icons.apps_outlined,
                  label: l10n.statsTopApp,
                  value: today.mostInterceptedApp ?? l10n.statsNoneYet,
                ),
                _StatTile(
                  icon: Icons.local_fire_department_outlined,
                  label: l10n.statsCurrentStreak,
                  value: l10n.statsDaysValue(today.currentStreak),
                  emphasized: today.currentStreak > 0,
                ),
              ],
            ),
            // F-14: day/week/month dashboard + weekly focus score ("beta").
            const DashSection(),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    return Semantics(
      label: '$label: $value',
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FokusRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(FokusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: emphasized
                    ? fokus.streakSignal
                    : theme.colorScheme.primary,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
