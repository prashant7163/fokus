import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/blocking_adapter.dart';
import '../../../core/blocking/providers.dart';
import '../../../core/constants.dart';
import '../../../core/data/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/presentation/widgets/app_picker_step.dart';
import '../../shared/app_icon_row.dart';

/// Start Session config (F-11, SCREENS §2): duration chips + custom
/// (5–480 min, spec §3.1), prompted-but-optional task anchor (80 chars),
/// blocked-apps summary with picker, strict-mode switch with an honest info
/// sheet. Start is never blocked — no apps or missing permissions just mean
/// an honestly-labeled timer-only session.
///
/// The per-session Recovery on/off toggle from SCREENS §2 is deferred to
/// F-13 presets — there is no contract seam for disabling recovery
/// per-session yet (noted in the F-11 MOM).
class SessionConfigScreen extends ConsumerStatefulWidget {
  const SessionConfigScreen({super.key});

  @override
  ConsumerState<SessionConfigScreen> createState() =>
      _SessionConfigScreenState();
}

class _SessionConfigScreenState extends ConsumerState<SessionConfigScreen> {
  int _durationMin = 30;
  bool _customActive = false;
  bool _strict = false;
  bool _starting = false;
  final _anchor = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default preselect = last used or 30 (SCREENS §2).
    ref.read(sessionRepositoryProvider).getMostRecentSession().then((last) {
      if (last != null && mounted) {
        setState(() {
          _durationMin = last.plannedMin;
          _customActive =
              !FokusConstants.sessionDurationsMin.contains(last.plannedMin);
          _strict = last.strictMode;
        });
      }
    });
  }

  @override
  void dispose() {
    _anchor.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await ref.read(sessionControllerProvider.notifier).start(
            plannedMin: _durationMin,
            taskAnchor: _anchor.text.trim().isEmpty ? null : _anchor.text.trim(),
            strictMode: _strict,
          );
      if (mounted) context.go(AppRoutes.session);
    } finally {
      _starting = false;
    }
  }

  Future<void> _pickCustom() async {
    final l10n = AppLocalizations.of(context);
    var value = _customActive ? _durationMin : 45;
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.configCustomTitle),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: value > FokusConstants.customDurationMinMin
                    ? () => setDialogState(() => value = value - 5)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  l10n.configCustomMinutes(value),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: value < FokusConstants.customDurationMaxMin
                    ? () => setDialogState(() => value = value + 5)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _durationMin = picked;
        _customActive = true;
      });
    }
  }

  Future<void> _editApps() async {
    final lists = ref.read(appListsRepositoryProvider);
    final current = await lists.getBlockedPackageNames();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.85,
        child: AppPickerStep(
          title: AppLocalizations.of(context).onbPickerBlockedTitle,
          subtitle: AppLocalizations.of(context).onbPickerBlockedSubtitle,
          initialSelection: current.toSet(),
          onDone: (apps) async {
            await lists.replaceBlockedApps([
              for (final app in apps)
                (packageName: app.packageName, appName: app.appName),
            ]);
            await ref
                .read(blockingAdapterProvider)
                .setBlockedApps([for (final app in apps) app.packageName]);
            ref.invalidate(blockedAppIconsProvider);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        ),
      ),
    );
    ref.invalidate(_configBlockedProvider); // refresh summary row
  }

  void _showStrictInfo() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FokusSpacing.lg,
            FokusSpacing.xs,
            FokusSpacing.lg,
            FokusSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.configStrictTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: FokusSpacing.sm),
              Text(
                l10n.configStrictInfo,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final blocked = ref.watch(_configBlockedProvider).value ?? const [];
    final icons = ref.watch(blockedAppIconsProvider).value ?? const {};
    final permissions = ref.watch(permissionStatusProvider).value;
    final limited = permissions != null && !permissions.blockingReady;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.configTitle),
        leading: BackButton(onPressed: () => context.go(AppRoutes.home)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(FokusSpacing.screenPadding),
        children: [
          Text(l10n.configDuration, style: theme.textTheme.titleMedium),
          const SizedBox(height: FokusSpacing.xs),
          Wrap(
            spacing: FokusSpacing.xs,
            children: [
              for (final min in FokusConstants.sessionDurationsMin)
                ChoiceChip(
                  label: Text('$min'),
                  selected: !_customActive && _durationMin == min,
                  onSelected: (_) => setState(() {
                    _durationMin = min;
                    _customActive = false;
                  }),
                ),
              ChoiceChip(
                label: Text(
                  _customActive
                      ? l10n.configCustomMinutes(_durationMin)
                      : l10n.configCustomChip,
                ),
                selected: _customActive,
                onSelected: (_) => _pickCustom(),
              ),
            ],
          ),
          const SizedBox(height: FokusSpacing.lg),
          TextField(
            controller: _anchor,
            maxLength: FokusConstants.taskAnchorMaxChars,
            decoration: InputDecoration(
              labelText: l10n.configAnchorLabel,
              helperText: l10n.configAnchorHelper,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: FokusSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.configAppsSelected(blocked.length)),
            subtitle: blocked.isEmpty
                ? Text(l10n.configTimerOnlyHint)
                : Padding(
                    padding: const EdgeInsets.only(top: FokusSpacing.xs),
                    child: AppIconRow(
                      apps: [
                        for (final app in blocked)
                          (packageName: app.packageName, appName: app.appName),
                      ],
                      icons: icons,
                    ),
                  ),
            trailing: TextButton(
              onPressed: _editApps,
              child: Text(l10n.configEditApps),
            ),
          ),
          const SizedBox(height: FokusSpacing.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Text(l10n.configStrictTitle),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18),
                  onPressed: _showStrictInfo,
                ),
              ],
            ),
            subtitle: Text(l10n.configStrictSubtitle),
            value: _strict,
            onChanged: (v) => setState(() => _strict = v),
          ),
          if (limited) ...[
            const SizedBox(height: FokusSpacing.xs),
            TextButton(
              onPressed: () => ref
                  .read(blockingAdapterProvider)
                  .requestPermission(PermissionKind.accessibility),
              child: Text(l10n.configPermissionHint),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FokusSpacing.md),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize:
                  const Size.fromHeight(FokusSpacing.minTouchTarget + 8),
            ),
            onPressed: _start,
            child: Text(l10n.configStart),
          ),
        ),
      ),
    );
  }
}

final _configBlockedProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(appListsRepositoryProvider).getBlockedApps(),
);
