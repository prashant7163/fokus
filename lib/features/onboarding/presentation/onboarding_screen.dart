import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/blocking_adapter.dart';
import '../../../core/blocking/providers.dart';
import '../../../core/data/providers.dart';
import '../../../core/prefs.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../recovery/presentation/widgets/recovery_illustration.dart';
import 'widgets/app_picker_step.dart';
import 'widgets/permissions_step.dart';

/// Onboarding (F-10, SCREENS §8, spec §3.11): three value screens →
/// **prominent accessibility disclosure with explicit consent — before any
/// settings redirect (Play policy)** → permission checklist → blocked-app
/// picker → always-needed allowlist (D-011) → home.
///
/// Every exit is respected: Skip, "Not now" on the disclosure and "I'll do
/// this later" all land in limited mode (timers work, blocking labeled
/// inactive — derived from permission state, no separate flag).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { valuePages, disclosure, permissions, pickBlocked, pickAllowed }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.valuePages;
  final _pager = PageController();

  /// Packages picked as blocked earlier in this flow — excluded from the
  /// allowlist step (D-011: an app is never both).
  Set<String> _pickedBlocked = const {};

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// Marks onboarding seen and leaves. Called from every terminal path —
  /// completing the flow AND all the "later" exits.
  Future<void> _finish() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.onboardingSeen, true);
    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _saveBlocked(List<InstalledApp> apps) async {
    await ref.read(appListsRepositoryProvider).replaceBlockedApps([
      for (final app in apps)
        (packageName: app.packageName, appName: app.appName),
    ]);
    await ref
        .read(blockingAdapterProvider)
        .setBlockedApps([for (final app in apps) app.packageName]);
    setState(() {
      _pickedBlocked = {for (final app in apps) app.packageName};
      _step = _Step.pickAllowed;
    });
  }

  Future<void> _saveAllowed(List<InstalledApp> apps) async {
    final repo = ref.read(appListsRepositoryProvider);
    for (final app in apps) {
      await repo.addAllowlistedApp(
        packageName: app.packageName,
        appName: app.appName,
      );
    }
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = switch (_step) {
      _Step.valuePages => _ValuePages(
          controller: _pager,
          onSkip: () => setState(() => _step = _Step.disclosure),
          onDone: () => setState(() => _step = _Step.disclosure),
        ),
      _Step.disclosure => _DisclosureStep(
          onConsent: () => setState(() => _step = _Step.permissions),
          onNotNow: _finish, // limited mode — no settings redirect ever fired.
        ),
      _Step.permissions => PermissionsStep(
          onContinue: () => setState(() => _step = _Step.pickBlocked),
          onLater: _finish,
        ),
      _Step.pickBlocked => AppPickerStep(
          key: const ValueKey('pickBlocked'),
          title: l10n.onbPickerBlockedTitle,
          subtitle: l10n.onbPickerBlockedSubtitle,
          excludePackages: const {},
          onDone: _saveBlocked,
        ),
      _Step.pickAllowed => AppPickerStep(
          key: const ValueKey('pickAllowed'),
          title: l10n.onbPickerAllowTitle,
          subtitle: l10n.onbPickerAllowSubtitle,
          excludePackages: _pickedBlocked,
          suggestCommonDistractors: false,
          onDone: _saveAllowed,
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_step), child: body),
        ),
      ),
    );
  }
}

// ─── value screens ─────────────────────────────────────────────────────────

class _ValuePages extends StatefulWidget {
  const _ValuePages({
    required this.controller,
    required this.onSkip,
    required this.onDone,
  });

  final PageController controller;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  @override
  State<_ValuePages> createState() => _ValuePagesState();
}

class _ValuePagesState extends State<_ValuePages> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final pages = <(String, String, String)>[
      (l10n.onbValue1Title, l10n.onbValue1Body, 'recovery_shrink'),
      (l10n.onbValue2Title, l10n.onbValue2Body, 'recovery_taskreset'),
      // The differentiator screen gets the best art (SCREENS §8.1).
      (l10n.onbValue3Title, l10n.onbValue3Body, 'recovery_breathe'),
    ];
    final last = _page == pages.length - 1;

    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(
                FokusSpacing.minTouchTarget,
                FokusSpacing.minTouchTarget,
              ),
            ),
            onPressed: widget.onSkip,
            child: Text(l10n.onbSkip),
          ),
        ),
        Expanded(
          child: PageView(
            controller: widget.controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final (title, body, asset) in pages)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FokusSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RecoveryIllustration(asset: asset, size: 180),
                      const SizedBox(height: FokusSpacing.xl),
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: FokusSpacing.sm),
                      Text(
                        body,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < pages.length; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.all(FokusSpacing.xxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page
                      ? theme.colorScheme.primary
                      : theme.extension<FokusColors>()!.ringTrack,
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(FokusSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(FokusSpacing.minTouchTarget),
              ),
              onPressed: last
                  ? widget.onDone
                  : () => widget.controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
              child: Text(last ? l10n.onbGetStarted : l10n.onbNext),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── accessibility disclosure ──────────────────────────────────────────────

/// Prominent disclosure (SCREENS §8.2, Play-policy-critical): full screen,
/// BEFORE any settings redirect; consent button placed after the body in
/// reading order so TalkBack cannot skip the text. Copy is a marked
/// PLACEHOLDER pending Prashant's verbatim approval — the marker is inside
/// the string on purpose so it cannot ship unnoticed.
class _DisclosureStep extends StatelessWidget {
  const _DisclosureStep({required this.onConsent, required this.onNotNow});

  final VoidCallback onConsent;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(FokusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reassuring ring mark, no alarming iconography (§8.2).
                  Icon(Icons.circle_outlined,
                      size: 28, color: theme.colorScheme.primary),
                  const SizedBox(height: FokusSpacing.md),
                  Text(l10n.onbDisclosureTitle,
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: FokusSpacing.md),
                  Text(l10n.onbDisclosureBody,
                      style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          const SizedBox(height: FokusSpacing.md),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            ),
            onPressed: onConsent,
            child: Text(l10n.onbDisclosureConsent),
          ),
          const SizedBox(height: FokusSpacing.xs),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            ),
            onPressed: onNotNow,
            child: Text(l10n.onbDisclosureNotNow),
          ),
        ],
      ),
    );
  }
}
