import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/blocking/blocking_adapter.dart';
import '../../../../core/blocking/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Multi-select app picker (F-10, SCREENS §8.4): search + toggle list with a
/// "Commonly blocked" section surfaced on top to cut taps. Used for the
/// blocked list and (with [suggestCommonDistractors] off) the D-011
/// always-needed allowlist. System/FOKUS/dialer/launcher never appear — the
/// native side already excludes them from getInstalledApps.
///
/// All-deselected is allowed (timer-only sessions). Icons are name-only for
/// now (icon bytes over the channel arrive with F-11 polish if needed).
class AppPickerStep extends ConsumerStatefulWidget {
  const AppPickerStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onDone,
    this.excludePackages = const {},
    this.suggestCommonDistractors = true,
    this.initialSelection = const {},
  });

  final String title;
  final String subtitle;
  final Set<String> excludePackages;
  final bool suggestCommonDistractors;
  final Set<String> initialSelection;
  final Future<void> Function(List<InstalledApp> selected) onDone;

  /// Well-known distractors for the "Commonly blocked" section (§8.4:
  /// Social, Video). Matched against what is actually installed.
  static const commonDistractors = {
    'com.instagram.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.google.android.youtube',
    'com.twitter.android',
    'com.facebook.katana',
    'com.snapchat.android',
    'com.reddit.frontpage',
    'com.netflix.mediaclient',
    'tv.twitch.android.app',
    'com.pinterest',
    'com.whatsapp',
  };

  @override
  ConsumerState<AppPickerStep> createState() => _AppPickerStepState();
}

class _AppPickerStepState extends ConsumerState<AppPickerStep> {
  List<InstalledApp>? _apps;
  late final Set<String> _selected = {...widget.initialSelection};
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(blockingAdapterProvider).getInstalledApps().then((apps) {
      if (!mounted) return;
      setState(() {
        _apps = apps
            .where((a) => !widget.excludePackages.contains(a.packageName))
            .toList();
      });
    });
  }

  Future<void> _done() async {
    if (_saving) return;
    _saving = true;
    final apps = _apps ?? const <InstalledApp>[];
    await widget.onDone(
      [for (final a in apps) if (_selected.contains(a.packageName)) a],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final apps = _apps;

    final matching = apps
            ?.where((a) =>
                _query.isEmpty ||
                a.appName.toLowerCase().contains(_query.toLowerCase()))
            .toList() ??
        const <InstalledApp>[];
    final common = widget.suggestCommonDistractors
        ? [
            for (final a in matching)
              if (AppPickerStep.commonDistractors.contains(a.packageName)) a,
          ]
        : const <InstalledApp>[];
    final rest = [
      for (final a in matching)
        if (!common.contains(a)) a,
    ];

    return Padding(
      padding: const EdgeInsets.all(FokusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: FokusSpacing.xxs),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: FokusSpacing.md),
          TextField(
            decoration: InputDecoration(
              hintText: l10n.onbPickerSearchHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FokusRadius.md),
              ),
              isDense: true,
            ),
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: FokusSpacing.sm),
          Expanded(
            child: apps == null
                ? const Center(child: CircularProgressIndicator())
                : matching.isEmpty
                    ? Center(child: Text(l10n.onbPickerEmptySearch))
                    : ListView(
                        children: [
                          if (common.isNotEmpty) ...[
                            _SectionLabel(l10n.onbPickerCommon),
                            for (final app in common) _row(app),
                            if (rest.isNotEmpty)
                              _SectionLabel(l10n.onbPickerAllApps),
                          ],
                          for (final app in rest) _row(app),
                        ],
                      ),
          ),
          const SizedBox(height: FokusSpacing.xs),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(FokusSpacing.minTouchTarget),
            ),
            onPressed: apps == null ? null : _done,
            child: Text(
              _selected.isEmpty
                  ? l10n.onbDone
                  : '${l10n.onbDone} · ${l10n.onbPickerSelected(_selected.length)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(InstalledApp app) {
    final selected = _selected.contains(app.packageName);
    return SwitchListTile(
      key: ValueKey(app.packageName),
      title: Text(app.appName),
      value: selected,
      contentPadding: EdgeInsets.zero,
      onChanged: (on) => setState(() {
        if (on) {
          _selected.add(app.packageName);
        } else {
          _selected.remove(app.packageName);
        }
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: FokusSpacing.sm,
        bottom: FokusSpacing.xxs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
