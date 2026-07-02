import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/blocking_adapter.dart';
import '../../../core/blocking/providers.dart';
import '../../../core/data/database.dart';
import '../../../core/data/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/streaks/streak_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/app_icon_row.dart';
import '../../suggestions/presentation/suggestion_card.dart';
import '../../stats/presentation/stats_screen.dart';

/// Home dashboard (F-11, SCREENS §1): answers "what now?" in under a second
/// and keeps the one-tap repeat sacred — 1 tap, no confirm, straight into a
/// running session (fokus-specs §3.1).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Most recent session — the repeat config source (F-11).
final _lastSessionProvider = FutureProvider.autoDispose<FocusSession?>(
  (ref) => ref.watch(sessionRepositoryProvider).getMostRecentSession(),
);

final _blockedAppsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(appListsRepositoryProvider).getBlockedApps(),
);

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _starting = false;

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
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionStatusProvider);
    }
  }

  /// The sacred one-tap repeat: last duration/anchor/strict + the current
  /// blocked list, straight to the running session. No confirmation step may
  /// ever be inserted here (FLOWS global principles).
  Future<void> _repeat(FocusSession last) async {
    if (_starting) return;
    _starting = true;
    try {
      await ref.read(sessionControllerProvider.notifier).start(
            plannedMin: last.plannedMin,
            taskAnchor: last.taskAnchor,
            strictMode: last.strictMode,
          );
      if (mounted) context.go(AppRoutes.session);
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    final last = ref.watch(_lastSessionProvider).value;
    final blocked = ref.watch(_blockedAppsProvider).value ?? const [];
    final icons = ref.watch(blockedAppIconsProvider).value ?? const {};
    final today = ref.watch(todayStatsProvider).value;
    final permissions = ref.watch(permissionStatusProvider).value;
    final limited = permissions != null && !permissions.blockingReady;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 2),
        ),
        actions: [
          if ((today?.currentStreak ?? 0) > 0)
            Semantics(
              button: true,
              label: l10n.homeStreakChipLabel(today!.currentStreak),
              child: ActionChip(
                avatar: Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: theme.extension<FokusColors>()!.streakSignal,
                ),
                label: Text('${today.currentStreak}'),
                onPressed: () => context.go(AppRoutes.stats),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(FokusSpacing.screenPadding),
        children: [
          Text(_greeting(l10n), style: theme.textTheme.headlineSmall),
          const SizedBox(height: FokusSpacing.md),
          if (limited) ...[
            _LimitedBanner(onFix: () {
              ref
                  .read(blockingAdapterProvider)
                  .requestPermission(PermissionKind.accessibility);
            }),
            const SizedBox(height: FokusSpacing.md),
          ],
          if (session.isRunning)
            _ResumeCard(session: session)
          else
            _HeroCard(
              last: last,
              blocked: blocked,
              icons: icons,
              limited: limited,
              onRepeat: _repeat,
            ),
          const SizedBox(height: FokusSpacing.sm),
          if (!session.isRunning)
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(FokusSpacing.minTouchTarget),
              ),
              onPressed: () => context.go(AppRoutes.newSession),
              child: Text(l10n.homeNewSession),
            ),
          const SizedBox(height: FokusSpacing.lg),
          if (today != null) _TodayCard(today: today),
          // F-17: opt-in, max one per day, dismissible, explained.
          const SuggestionCard(),
        ],
      ),
    );
  }

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 18) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.last,
    required this.blocked,
    required this.icons,
    required this.limited,
    required this.onRepeat,
  });

  final FocusSession? last;
  final List<BlockedApp> blocked;
  final Map<String, dynamic> icons;
  final bool limited;
  final void Function(FocusSession) onRepeat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    final hasHistory = last != null;

    return Card(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasHistory
                        ? l10n.homeRepeatTitle
                        : l10n.homeFirstSessionTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (hasHistory && last!.strictMode)
                  _Badge(text: l10n.homeStrictBadge),
              ],
            ),
            const SizedBox(height: FokusSpacing.sm),
            if (blocked.isNotEmpty)
              AppIconRow(
                apps: [
                  for (final app in blocked)
                    (packageName: app.packageName, appName: app.appName),
                ],
                icons: icons.cast(),
              ),
            if (limited) ...[
              const SizedBox(height: FokusSpacing.xs),
              Text(
                l10n.homeTimerOnlyLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: FokusSpacing.md),
            Semantics(
              button: true,
              label: hasHistory
                  ? l10n.homeRepeatCtaLabel(last!.plannedMin, blocked.length)
                  : l10n.homeFirstSessionCta,
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: fokus.focusGradient,
                    borderRadius: BorderRadius.circular(FokusRadius.full),
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize:
                          const Size.fromHeight(FokusSpacing.minTouchTarget + 8),
                    ),
                    onPressed: () {
                      if (hasHistory) {
                        onRepeat(last!);
                      } else {
                        context.go(AppRoutes.newSession);
                      }
                    },
                    child: Text(
                      hasHistory
                          ? l10n.homeRepeatCta(last!.plannedMin)
                          : l10n.homeFirstSessionCta,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final remaining = session.remaining;
    final mm = remaining.inMinutes;
    final ss = remaining.inSeconds.remainder(60);
    final text = '$mm:${ss.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeResumeTitle(text),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: FokusSpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(FokusSpacing.minTouchTarget),
              ),
              onPressed: () => context.go(AppRoutes.session),
              child: Text(l10n.homeResumeCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});

  final TodayStats today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget stat(String label, String value) => Semantics(
          label: '$label: $value',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleMedium),
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        );

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsTodayTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: FokusSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: stat(
                    l10n.statsFocusMinutes,
                    l10n.statsMinutesValue(today.focusMinutes),
                  ),
                ),
                Expanded(
                  child: stat(
                    l10n.statsDistractionsBlocked,
                    '${today.distractionsBlocked}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: FokusSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: stat(
                    l10n.statsTopApp,
                    today.mostInterceptedApp ?? l10n.statsNoneYet,
                  ),
                ),
                Expanded(
                  child: stat(
                    l10n.statsCurrentStreak,
                    l10n.statsDaysValue(today.currentStreak),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FokusSpacing.md,
          vertical: FokusSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(FokusRadius.full),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.homeLimitedBanner,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onFix,
              child: Text(l10n.homeLimitedFix),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

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
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(FokusRadius.full),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
