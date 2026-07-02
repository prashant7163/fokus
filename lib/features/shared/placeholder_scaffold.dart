import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Temporary scaffold used by feature stubs until their tasks land.
/// Not part of the design system — delete when the last stub dies.
class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({super.key, required this.title, this.taskId});

  final String title;

  /// Taskboard ID that will replace this stub (shown for orientation).
  final String? taskId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: FokusSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (taskId != null) ...[
                const SizedBox(height: FokusSpacing.xs),
                Text(
                  taskId!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
