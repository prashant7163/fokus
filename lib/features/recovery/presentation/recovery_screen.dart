import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../shared/placeholder_scaffold.dart';

/// Recovery-flow stub — replaced by F-07.
class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key, this.preselectedModule});

  /// Module pre-selected by the deep link (`fokus://recovery?module=breathe`
  /// from the intercept's proactive hint). Values per CONTRACTS §2
  /// RecoveryType names; F-07 consumes this.
  final String? preselectedModule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScaffold(
      title: l10n.recoveryTitle,
      taskId: preselectedModule == null
          ? 'F-07'
          : 'F-07 · module=$preselectedModule',
    );
  }
}
