import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database.dart';
import '../../../core/data/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/feedback_sampler.dart';

/// Post-session micro-feedback (F-16, spec §3.9, SCREENS §7 step 5):
/// sampled 1 in 3 completions, 😊/😐/😔 with text labels, one follow-up
/// chip row on 😔, fully skippable. Renders nothing when not sampled or
/// already answered.
class FeedbackRow extends ConsumerStatefulWidget {
  const FeedbackRow({super.key});

  @override
  ConsumerState<FeedbackRow> createState() => _FeedbackRowState();
}

/// Whether THIS completion is sampled: completed count says ask, and no
/// entry exists yet for this session (rebuild-safe).
final _shouldAskProvider = FutureProvider.autoDispose<bool>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  final id = session.sessionId;
  if (id == null || session.status != SessionStatus.completed) return false;
  final db = ref.watch(databaseProvider);
  final completed = await (db.select(db.focusSessions)
        ..where((s) => s.status.equals(SessionStatus.completed.name))
        ..orderBy([(s) => OrderingTerm.asc(s.startTime)]))
      .get();
  if (!FeedbackSampler.shouldAsk(completed.length)) return false;
  return !await ref.read(feedbackRepositoryProvider).existsForSession(id);
});

class _FeedbackRowState extends ConsumerState<FeedbackRow> {
  int? _rating;
  bool _done = false;

  Future<void> _submit(int rating, {String? reason}) async {
    final session = ref.read(sessionControllerProvider);
    await ref.read(feedbackRepositoryProvider).addPostSession(
          rating: rating,
          reason: reason,
          contextJson: jsonEncode({
            'sessionId': session.sessionId,
            'plannedMin': session.plannedMin,
            'strictMode': session.strictMode,
          }),
        );
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ask = ref.watch(_shouldAskProvider).value ?? false;
    if (!ask || _done) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: FokusSpacing.md),
        Text(l10n.feedbackPrompt, style: theme.textTheme.titleMedium),
        const SizedBox(height: FokusSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _emoji('😊', l10n.feedbackGood, 3),
            _emoji('😐', l10n.feedbackOkay, 2),
            _emoji('😔', l10n.feedbackRough, 1),
          ],
        ),
        if (_rating == 1) ...[
          const SizedBox(height: FokusSpacing.xs),
          Wrap(
            spacing: FokusSpacing.xxs,
            alignment: WrapAlignment.center,
            children: [
              _reasonChip(l10n.feedbackTooLong, 'tooLong'),
              _reasonChip(l10n.feedbackInterrupted, 'interrupted'),
              _reasonChip(l10n.feedbackBlockingFailed, 'blockingFailed'),
              _reasonChip(l10n.feedbackOther, 'other'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _emoji(String emoji, String label, int rating) {
    final selected = _rating == rating;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(FokusRadius.md),
        onTap: () {
          if (rating == 1) {
            // 😔 waits for the follow-up chip before writing (spec §3.9).
            setState(() => _rating = 1);
          } else {
            _submit(rating);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(FokusSpacing.xs),
          constraints: const BoxConstraints(
            minWidth: FokusSpacing.minTouchTarget,
            minHeight: FokusSpacing.minTouchTarget,
          ),
          decoration: selected
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(FokusRadius.md),
                )
              : null,
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }

  Widget _reasonChip(String label, String code) => ActionChip(
        label: Text(label),
        onPressed: () => _submit(1, reason: code),
      );
}
