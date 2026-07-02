import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/blocking_adapter.dart';
import '../../../core/blocking/providers.dart';
import '../../../core/data/providers.dart';
import '../../../core/prefs.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/presentation/widgets/app_picker_step.dart';

/// Settings / permissions-health (F-12, SCREENS §9): permission health on
/// top (the red banner is the ONE place error-red is warranted — mid-session
/// loss), theme, Smart Suggestions opt-in, app-list shortcuts (incl. the
/// D-011 allowlist, editable per contract), the privacy trust anchor, about.
///
/// Notification + per-session recovery toggles from SCREENS §9 arrive with
/// F-13/F-16 — no dead toggles before something consumes them (D-020).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  static const _version = '0.1.0'; // pubspec.yaml version — bump together.

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

  Future<void> _editList({required bool allowlist}) async {
    final l10n = AppLocalizations.of(context);
    final lists = ref.read(appListsRepositoryProvider);
    final blocked = await lists.getBlockedPackageNames();
    final allowed = [
      for (final app in await lists.getAllowlistedApps()) app.packageName,
    ];
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.85,
        child: AppPickerStep(
          title: allowlist ? l10n.setAllowedApps : l10n.setBlockedApps,
          subtitle: allowlist
              ? l10n.onbPickerAllowSubtitle
              : l10n.onbPickerBlockedSubtitle,
          // An app is never on both lists (D-011).
          excludePackages: allowlist ? blocked.toSet() : allowed.toSet(),
          suggestCommonDistractors: !allowlist,
          initialSelection:
              allowlist ? allowed.toSet() : blocked.toSet(),
          onDone: (apps) async {
            if (allowlist) {
              for (final pkg in allowed) {
                await lists.removeAllowlistedApp(pkg);
              }
              for (final app in apps) {
                await lists.addAllowlistedApp(
                  packageName: app.packageName,
                  appName: app.appName,
                );
              }
            } else {
              await lists.replaceBlockedApps([
                for (final app in apps)
                  (packageName: app.packageName, appName: app.appName),
              ]);
              await ref
                  .read(blockingAdapterProvider)
                  .setBlockedApps([for (final app in apps) app.packageName]);
              ref.invalidate(blockedAppIconsProvider);
            }
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(permissionStatusProvider).value;
    final lostPermission =
        ref.watch(sessionControllerProvider).lostPermission;
    final themeMode = ref.watch(themeModeProvider);
    final suggestions = ref.watch(smartSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: BackButton(onPressed: () => context.go(AppRoutes.home)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(FokusSpacing.screenPadding),
        children: [
          if (lostPermission != null) ...[
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(FokusSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(FokusRadius.md),
                ),
                child: Text(
                  l10n.setPermsLostBanner,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
            const SizedBox(height: FokusSpacing.md),
          ],
          _PermissionsCard(status: status),
          const SizedBox(height: FokusSpacing.lg),
          Text(l10n.setAppearance, style: theme.textTheme.titleMedium),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeModeProvider.notifier).set(mode);
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text(l10n.setThemeSystem),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text(l10n.setThemeLight),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text(l10n.setThemeDark),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.setSuggestionsTitle),
            subtitle: Text(l10n.setSuggestionsSubtitle),
            value: suggestions,
            onChanged: (v) =>
                ref.read(smartSuggestionsProvider.notifier).set(v),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_outlined),
            title: Text(l10n.presetsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.presets),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.block_outlined),
            title: Text(l10n.setBlockedApps),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editList(allowlist: false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite_outline),
            title: Text(l10n.setAllowedApps),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editList(allowlist: true),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.setPrivacyTitle),
            subtitle: Text(l10n.setPrivacyBody),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.setAboutTitle),
            subtitle: Text(l10n.setAboutVersion(_version)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.setLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: _version,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsCard extends ConsumerWidget {
  const _PermissionsCard({required this.status});

  final PermissionState? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final rows = <(PermissionKind, String)>[
      (PermissionKind.accessibility, l10n.permAccessibilityName),
      (PermissionKind.usageStats, l10n.permUsageName),
      (PermissionKind.notifications, l10n.permNotificationsName),
      (PermissionKind.batteryExemption, l10n.permBatteryName),
    ];
    final allGood = status?.allGranted ?? false;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.setPermsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: FokusSpacing.xxs),
            Text(
              allGood ? l10n.setPermsAllGood : l10n.setPermsDegraded,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: FokusSpacing.xs),
            for (final (kind, name) in rows)
              Semantics(
                label:
                    '$name: ${(status?.isGranted(kind) ?? false) ? l10n.permStatusActive : l10n.permStatusNeeded}',
                child: Row(
                  children: [
                    Icon(
                      (status?.isGranted(kind) ?? false)
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: (status?.isGranted(kind) ?? false)
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: FokusSpacing.xs),
                    Expanded(child: Text(name)),
                    if (!(status?.isGranted(kind) ?? true))
                      TextButton(
                        onPressed: () => ref
                            .read(blockingAdapterProvider)
                            .requestPermission(kind),
                        child: Text(l10n.setFix),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
