import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/providers.dart';
import '../../../core/constants.dart';
import '../../../core/data/database.dart';
import '../../../core/data/providers.dart';
import '../../../core/data/repositories/preset_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/presentation/widgets/app_picker_step.dart';
import '../application/schedule_sync_service.dart';

/// Presets & schedules (F-13, fokus-specs §3.7): named session bundles with
/// one-tap start and recurring auto-start schedules. Every mutation re-syncs
/// the native WorkManager mirror.
class PresetsScreen extends ConsumerStatefulWidget {
  const PresetsScreen({super.key});

  @override
  ConsumerState<PresetsScreen> createState() => _PresetsScreenState();
}

final _presetsProvider = StreamProvider.autoDispose<List<Preset>>(
  (ref) => ref.watch(presetRepositoryProvider).watchPresets(),
);

final _schedulesProvider =
    FutureProvider.autoDispose.family<List<Schedule>, int>(
  (ref, presetId) =>
      ref.watch(presetRepositoryProvider).schedulesForPreset(presetId),
);

class _PresetsScreenState extends ConsumerState<PresetsScreen> {
  bool _busy = false;

  Future<void> _sync() => ref.read(scheduleSyncProvider).sync();

  Future<void> _startNow(Preset preset) async {
    if (_busy) return;
    _busy = true;
    try {
      final packages = PresetRepository.decodePackages(preset);
      // Resolve app names for the blocked_apps list (preset stores ids only).
      final installed =
          await ref.read(blockingAdapterProvider).getInstalledApps();
      final names = {for (final a in installed) a.packageName: a.appName};
      await ref.read(appListsRepositoryProvider).replaceBlockedApps([
        for (final pkg in packages)
          (packageName: pkg, appName: names[pkg] ?? pkg),
      ]);
      await ref.read(blockingAdapterProvider).setBlockedApps(packages);
      ref.invalidate(blockedAppIconsProvider);
      await ref.read(sessionControllerProvider.notifier).start(
            plannedMin: preset.durationMin,
            taskAnchor: preset.name,
            strictMode: preset.strictMode,
            recoveryEnabled: preset.recoveryEnabled,
          );
      if (mounted) context.go(AppRoutes.session);
    } finally {
      _busy = false;
    }
  }

  Future<void> _editPreset({Preset? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PresetEditor(
        existing: existing,
        onSaved: () async {
          await _sync();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  Future<void> _editSchedule(Preset preset, {Schedule? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ScheduleEditor(
        preset: preset,
        existing: existing,
        onSaved: () async {
          await _sync();
          ref.invalidate(_schedulesProvider(preset.id));
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final presets = ref.watch(_presetsProvider).value ?? const <Preset>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.presetsTitle),
        leading: BackButton(onPressed: () => context.go(AppRoutes.settings)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPreset(),
        icon: const Icon(Icons.add),
        label: Text(l10n.presetsNew),
      ),
      body: presets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(FokusSpacing.xl),
                child: Text(
                  l10n.presetsEmpty,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(FokusSpacing.screenPadding),
              children: [
                for (final preset in presets) _presetCard(preset),
                const SizedBox(height: 80), // FAB clearance
              ],
            ),
    );
  }

  Widget _presetCard(Preset preset) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final schedules =
        ref.watch(_schedulesProvider(preset.id)).value ?? const <Schedule>[];
    final packages = PresetRepository.decodePackages(preset);

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.lg),
      ),
      margin: const EdgeInsets.only(bottom: FokusSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(preset.name,
                      style: theme.textTheme.titleMedium),
                ),
                if (preset.strictMode)
                  Padding(
                    padding: const EdgeInsets.only(right: FokusSpacing.xs),
                    child: Icon(Icons.lock_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: l10n.configEditApps,
                  onPressed: () => _editPreset(existing: preset),
                ),
              ],
            ),
            Text(
              l10n.presetSummary(preset.durationMin, packages.length),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: FokusSpacing.xs),
            for (final schedule in schedules)
              _scheduleRow(preset, schedule),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.alarm_add_outlined, size: 18),
                  label: Text(l10n.scheduleAdd),
                  onPressed: () => _editSchedule(preset),
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () => _startNow(preset),
                  child: Text(l10n.presetStartNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(Preset preset, Schedule schedule) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = PresetRepository.decodeDays(schedule);
    final labels = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];
    final dayText =
        [for (final d in days..sort()) labels[d - 1]].join(' ');

    return InkWell(
      onTap: () => _editSchedule(preset, existing: schedule),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FokusSpacing.xxs),
        child: Row(
          children: [
            Icon(
              schedule.enabled
                  ? Icons.alarm_on_outlined
                  : Icons.alarm_off_outlined,
              size: 18,
              color: schedule.enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: FokusSpacing.xs),
            Text(
              l10n.scheduleAt(schedule.startLocalTime, dayText),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: schedule.enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── preset editor ──────────────────────────────────────────────────────────

class _PresetEditor extends ConsumerStatefulWidget {
  const _PresetEditor({this.existing, required this.onSaved});

  final Preset? existing;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_PresetEditor> createState() => _PresetEditorState();
}

class _PresetEditorState extends ConsumerState<_PresetEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late int _durationMin = widget.existing?.durationMin ?? 30;
  late bool _strict = widget.existing?.strictMode ?? false;
  late bool _recovery = widget.existing?.recoveryEnabled ?? true;
  late List<String> _packages = widget.existing == null
      ? const []
      : PresetRepository.decodePackages(widget.existing!);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) {
      // New preset defaults to the currently blocked apps.
      ref
          .read(appListsRepositoryProvider)
          .getBlockedPackageNames()
          .then((packages) {
        if (mounted) setState(() => _packages = packages);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickApps() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.85,
        child: AppPickerStep(
          title: l10n.onbPickerBlockedTitle,
          subtitle: l10n.onbPickerBlockedSubtitle,
          initialSelection: _packages.toSet(),
          onDone: (apps) async {
            setState(
              () => _packages = [for (final a in apps) a.packageName],
            );
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    _saving = true;
    try {
      final repo = ref.read(presetRepositoryProvider);
      if (widget.existing == null) {
        await repo.createPreset(
          name: _name.text.trim(),
          durationMin: _durationMin,
          strictMode: _strict,
          recoveryEnabled: _recovery,
          blockedPackages: _packages,
        );
      } else {
        await repo.updatePreset(
          widget.existing!.id,
          name: _name.text.trim(),
          durationMin: _durationMin,
          strictMode: _strict,
          recoveryEnabled: _recovery,
          blockedPackages: _packages,
        );
      }
      await widget.onSaved();
    } finally {
      _saving = false;
    }
  }

  Future<void> _delete() async {
    if (_saving || widget.existing == null) return;
    _saving = true;
    try {
      await ref
          .read(presetRepositoryProvider)
          .deletePreset(widget.existing!.id);
      await widget.onSaved();
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: FokusSpacing.lg,
        right: FokusSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + FokusSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.presetNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: FokusSpacing.md),
          Wrap(
            spacing: FokusSpacing.xs,
            children: [
              for (final min in FokusConstants.sessionDurationsMin)
                ChoiceChip(
                  label: Text('$min'),
                  selected: _durationMin == min,
                  onSelected: (_) => setState(() => _durationMin = min),
                ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.configAppsSelected(_packages.length)),
            trailing: TextButton(
              onPressed: _pickApps,
              child: Text(l10n.configEditApps),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.configStrictTitle),
            value: _strict,
            onChanged: (v) => setState(() => _strict = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.presetRecoveryToggle),
            value: _recovery,
            onChanged: (v) => setState(() => _recovery = v),
          ),
          const SizedBox(height: FokusSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            ),
            onPressed: _save,
            child: Text(l10n.presetSave),
          ),
          if (widget.existing != null)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(FokusSpacing.minTouchTarget),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _delete,
              child: Text(l10n.presetDelete),
            ),
        ],
      ),
    );
  }
}

// ─── schedule editor ────────────────────────────────────────────────────────

class _ScheduleEditor extends ConsumerStatefulWidget {
  const _ScheduleEditor({
    required this.preset,
    this.existing,
    required this.onSaved,
  });

  final Preset preset;
  final Schedule? existing;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends ConsumerState<_ScheduleEditor> {
  late final Set<int> _days = widget.existing == null
      ? <int>{}
      : PresetRepository.decodeDays(widget.existing!).toSet();
  late TimeOfDay _time = widget.existing == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : _parse(widget.existing!.startLocalTime);
  late bool _enabled = widget.existing?.enabled ?? true;
  bool _saving = false;

  static TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String get _hhmm =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving || _days.isEmpty) return;
    _saving = true;
    try {
      final repo = ref.read(presetRepositoryProvider);
      if (widget.existing == null) {
        await repo.createSchedule(
          presetId: widget.preset.id,
          daysOfWeek: _days.toList()..sort(),
          startLocalTime: _hhmm,
          enabled: _enabled,
        );
      } else {
        await repo.updateSchedule(
          widget.existing!.id,
          daysOfWeek: _days.toList()..sort(),
          startLocalTime: _hhmm,
          enabled: _enabled,
        );
      }
      await widget.onSaved();
    } finally {
      _saving = false;
    }
  }

  Future<void> _delete() async {
    if (_saving || widget.existing == null) return;
    _saving = true;
    try {
      await ref
          .read(presetRepositoryProvider)
          .deleteSchedule(widget.existing!.id);
      await widget.onSaved();
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FokusSpacing.lg,
        0,
        FokusSpacing.lg,
        FokusSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.preset.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: FokusSpacing.sm),
          Wrap(
            spacing: FokusSpacing.xxs,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(labels[day - 1]),
                  selected: _days.contains(day),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _days.add(day);
                    } else {
                      _days.remove(day);
                    }
                  }),
                ),
            ],
          ),
          if (_days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: FokusSpacing.xxs),
              child: Text(
                l10n.scheduleDaysHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(_hhmm),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (picked != null) setState(() => _time = picked);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.scheduleEnabled),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          Text(
            l10n.scheduleAutoStartNote,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: FokusSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            ),
            onPressed: _days.isEmpty ? null : _save,
            child: Text(l10n.presetSave),
          ),
          if (widget.existing != null)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(FokusSpacing.minTouchTarget),
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _delete,
              child: Text(l10n.presetDelete),
            ),
        ],
      ),
    );
  }
}
