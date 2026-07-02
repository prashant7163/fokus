import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../shared/placeholder_scaffold.dart';

/// Structured exit-flow stub — replaced by F-08. Reached via the
/// `fokus://exit` deep link from InterceptActivity's emergency-exit CTA
/// and (later) the active-session "End session" affordance.
class ExitScreen extends StatelessWidget {
  const ExitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScaffold(title: l10n.exitTitle, taskId: 'F-08');
  }
}
