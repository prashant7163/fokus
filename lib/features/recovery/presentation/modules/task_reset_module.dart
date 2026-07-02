import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Task reset module body (SCREENS §5.2): "What's the next smallest step?" +
/// one calm text field. Completing is always allowed with an empty field
/// (never force input). The typed step is surfaced via [onChanged] so the
/// screen can act on it at Resume.
///
/// CONTRACT NOTE (flagged, not invented): SCREENS §5.2 says the step is "saved
/// to session notes". `focus_sessions` (CONTRACTS §3) has no notes/next-step
/// column — only `taskAnchor`, which is the original focus intent and must not
/// be overwritten. Persisting the note needs a CONTRACTS §3 column addition
/// (tech-lead ruling). Until then the note lives in the recovery flow only; the
/// RecoveryEvent(type=taskReset) is still logged. See F-07 summary.
class TaskResetModule extends StatefulWidget {
  const TaskResetModule({super.key, this.onChanged, this.controller});

  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  @override
  State<TaskResetModule> createState() => _TaskResetModuleState();
}

class _TaskResetModuleState extends State<TaskResetModule> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.recoveryTaskResetPrompt,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FokusSpacing.xl),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          // Avoid an autofocus keyboard jump-scare (SCREENS §5.2) — tap to focus.
          autofocus: false,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: l10n.recoveryTaskResetHint,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FokusRadius.md),
            ),
          ),
        ),
      ],
    );
  }
}
