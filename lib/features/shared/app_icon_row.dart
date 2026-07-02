import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Compact row of app icons (max [maxIcons] + "+N" overflow) used on the
/// home hero, config summary, and active session (F-11). Icons come from
/// [blockedAppIconsProvider]; a missing icon falls back to a letter glyph so
/// the row never looks broken.
class AppIconRow extends StatelessWidget {
  const AppIconRow({
    super.key,
    required this.apps,
    required this.icons,
    this.maxIcons = 5,
    this.size = 32,
  });

  /// (packageName, appName) pairs, in display order.
  final List<({String packageName, String appName})> apps;
  final Map<String, Uint8List> icons;
  final int maxIcons;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = apps.take(maxIcons).toList();
    final overflow = apps.length - shown.length;

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final app in shown)
            Padding(
              padding: const EdgeInsets.only(right: FokusSpacing.xs),
              child: SizedBox(
                width: size,
                height: size,
                child: icons[app.packageName] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(size / 4),
                        child: Image.memory(
                          icons[app.packageName]!,
                          width: size,
                          height: size,
                          gaplessPlayback: true,
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          app.appName.isEmpty
                              ? '?'
                              : app.appName[0].toUpperCase(),
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
              ),
            ),
          if (overflow > 0)
            Text(
              l10n.homeMoreApps(overflow),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
