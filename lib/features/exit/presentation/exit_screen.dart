import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/streaks/streak_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/exit_flow.dart';

/// Structured exit flow (F-08, fokus-specs §3.4, SCREENS §6).
///
/// Two entries, one route:
/// - `/exit` — the "Why are you leaving?" sheet with exactly five reasons.
///   Reached from the active session's "End session", recovery's "End
///   session" (first pass), and the `fokus://exit` deep link.
/// - `/exit?confirm=<reason>` — confirm-abort: recovery that was *itself*
///   entered from this sheet ends here with the already-given reason instead
///   of asking again (no interrogation loops — FLOWS §4). Non-strict aborts
///   immediately; strict shows the honest-consequences step first.
///   Emergency never passes through here (spec §2.3: never gated).
class ExitScreen extends ConsumerStatefulWidget {
  const ExitScreen({super.key, this.confirmReasonName});

  /// [ExitReason] name for the confirm-abort entry; null shows the sheet.
  final String? confirmReasonName;

  @override
  ConsumerState<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends ConsumerState<ExitScreen> {
  bool _resolving = false;

  ExitReason? get _confirmReason {
    final name = widget.confirmReasonName;
    if (name == null) return null;
    for (final r in ExitReason.values) {
      if (r.name == name) return r;
    }
    // Unknown confirm param (forged/stale browsable deep link — M4 review
    // P2): fall back to ASKING, never to a silent abort with a made-up
    // reason. The genuine hand-back always carries a valid enum name.
    return null;
  }

  /// Latches [_resolving] around [action] and ALWAYS releases it: a thrown
  /// terminal call must never leave the CTAs and the PopScope back handler
  /// permanently dead — this screen is the strict-mode escape hatch (M4
  /// review P1). Failures are reported and surfaced as a retry snackbar;
  /// releasing after a successful navigation is harmless (the widget is
  /// already unmounting).
  Future<void> _guarded(Future<void> Function() action) async {
    if (_resolving) return;
    _resolving = true;
    final messenger = ScaffoldMessenger.of(context);
    final retry = AppLocalizations.of(context).errorTryAgain;
    try {
      await action();
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s));
      messenger.showSnackBar(SnackBar(content: Text(retry)));
    } finally {
      _resolving = false;
    }
  }

  SessionController get _controller =>
      ref.read(sessionControllerProvider.notifier);
  SessionState get _session => ref.read(sessionControllerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reconcile(_session);
    });
  }

  /// Cold-start deep links (intercept CTA3) land here before the async DB
  /// hydration resolves — the transient initial `idle` must NOT be read as
  /// "no session" (M2 finding). Every decision waits for [SessionState
  /// .hydrated]; build() re-invokes this via ref.listen when it flips.
  void _reconcile(SessionState session) {
    if (_resolving || !session.hydrated) return;
    final reason = _confirmReason;
    if (!session.isRunning) {
      // Stale deep link or the session already ended — nothing to exit.
      _resolving = true;
      context.go(AppRoutes.home);
    } else if (reason != null && !session.strictMode) {
      // Non-strict confirm-abort: the reason was already given in the
      // sheet; asking again would be the interrogation loop FLOWS §4 bans.
      _abortNow(reason);
    }
  }

  // --- terminal paths --------------------------------------------------

  Future<void> _abortNow(ExitReason reason) => _guarded(() async {
        final messenger = ScaffoldMessenger.of(context);
        final ended = AppLocalizations.of(context).exitSessionEnded;
        await _controller.abort(exitReason: reason);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(ended)));
        context.go(AppRoutes.home);
      });

  Future<void> _pick(ExitReason reason) async {
    // The two sheet outcomes run AFTER the guard releases: their own CTAs
    // (_grantPass, _stay) latch for themselves and would bail if this method
    // still held _resolving while the sheet is up.
    ExitOutcome? sheet;
    await _guarded(() async {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // CONTRACTS §2: the reason is logged on every early-exit *attempt*,
      // whether or not the session ends.
      await _controller.recordExitReasonAttempt(reason);
      if (!mounted) return;

      switch (ExitFlow.outcomeFor(reason, strictMode: _session.strictMode)) {
        case ExitOutcome.completeAsFinished:
          await _controller.finishTask();
          if (!mounted) return;
          context.go(AppRoutes.sessionComplete);

        case ExitOutcome.exitNow:
          await _controller.emergencyExit();
          if (!mounted) return;
          messenger
              .showSnackBar(SnackBar(content: Text(l10n.exitSessionEnded)));
          context.go(AppRoutes.home);

        case ExitOutcome.recoveryHub:
          context.go('${AppRoutes.recovery}?exitReason=${reason.name}');

        case ExitOutcome.recoveryBreathe:
          context.go(
            '${AppRoutes.recovery}?module=breathe&exitReason=${reason.name}',
          );

        case ExitOutcome.pickPassApp:
        case ExitOutcome.strictDenied:
          sheet = ExitFlow.outcomeFor(reason, strictMode: _session.strictMode);
      }
    });
    if (!mounted) return;
    switch (sheet) {
      case ExitOutcome.pickPassApp:
        await _showPassPicker();
      case ExitOutcome.strictDenied:
        await _showStrictDenied();
      default:
        break;
    }
  }

  /// Lock-break redemption (spec §3.5): ends as completed-via-lockbreak —
  /// streak preserved, celebrated gracefully. Offered only when redeemable
  /// (token exists + weekly cap not hit — [lockBreakOfferProvider]).
  Future<void> _redeemLockBreak() => _guarded(() async {
        await _controller.redeemLockBreak();
        if (!mounted) return;
        context.go(AppRoutes.sessionComplete);
      });

  /// "Stay in focus" — the friendly default. Composes recovery resume when
  /// the sheet was reached mid-recovery.
  Future<void> _stay() => _guarded(() async {
        if (_session.status == SessionStatus.recoveryInProgress) {
          await _controller.resumeRecovery();
        }
        if (!mounted) return;
        context.go(AppRoutes.session);
      });

  // --- needApp sub-states ------------------------------------------------

  Future<void> _showPassPicker() async {
    final l10n = AppLocalizations.of(context);
    final apps = await ref.read(appListsRepositoryProvider).getBlockedApps();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: FokusSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FokusSpacing.lg,
                vertical: FokusSpacing.xs,
              ),
              child: Text(
                l10n.exitPassPickerTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final app in apps)
              ListTile(
                minTileHeight: FokusSpacing.minTouchTarget + 8,
                title: Text(app.appName),
                onTap: () => _grantPass(
                  sheetContext,
                  packageName: app.packageName,
                  appName: app.appName,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _grantPass(
    BuildContext sheetContext, {
    required String packageName,
    required String appName,
  }) =>
      _guarded(() async {
        final l10n = AppLocalizations.of(context);
        final messenger = ScaffoldMessenger.of(context);
        await _controller.grantAppPass(packageName);
        if (!mounted) return;
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.exitPassGranted(appName))),
        );
        context.go(AppRoutes.session);
      });

  Future<void> _showStrictDenied() async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.exitStrictDeniedTitle,
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: FokusSpacing.xs),
              Text(
                l10n.exitStrictDeniedBody,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: FokusSpacing.lg),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(FokusSpacing.minTouchTarget),
                ),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.go(
                    '${AppRoutes.recovery}?exitReason=${ExitReason.needApp.name}',
                  );
                },
                child: Text(l10n.exitStrictDeniedRecovery),
              ),
              const SizedBox(height: FokusSpacing.xs),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(FokusSpacing.minTouchTarget),
                ),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _stay();
                },
                child: Text(l10n.exitStrictDeniedBack),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Re-decide whenever the session changes: hydration concluding, or a
    // session that ends while the user is deciding (timer end, native stop)
    // — both route away quietly. _resolving guards the races where this
    // screen caused the transition itself.
    ref.listen(sessionControllerProvider, (_, next) => _reconcile(next));
    final session = ref.watch(sessionControllerProvider);
    final confirmReason = _confirmReason;

    final Widget body;
    if (!session.hydrated || !session.isRunning) {
      // Waiting for hydration, or redirecting home (_reconcile).
      body = const SizedBox.shrink();
    } else if (confirmReason != null) {
      body = session.strictMode
          ? _StrictConsequences(
              onEndAnyway: () => _abortNow(confirmReason),
              onKeepGoing: _stay,
              onRedeemToken: _redeemLockBreak,
            )
          : const SizedBox.shrink(); // aborting + redirecting (_reconcile).
    } else {
      body = _ReasonSheet(onPick: _pick, onStay: _stay);
    }

    final fokus = Theme.of(context).extension<FokusColors>()!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // System back = the friendly default: stay in focus.
        if (!didPop && session.isRunning) _stay();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: fokus.calmWash),
          child: SafeArea(child: body),
        ),
      ),
    );
  }
}

/// The five reasons + "Stay in focus", bottom-anchored like the sheet it is
/// on the active-session screen (SCREENS §6: sheet over dimmed session).
class _ReasonSheet extends StatelessWidget {
  const _ReasonSheet({required this.onPick, required this.onStay});

  final void Function(ExitReason) onPick;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final options = <(ExitReason, IconData, String, String)>[
      (
        ExitReason.finishedTask,
        Icons.check_circle_outline,
        l10n.exitReasonFinished,
        l10n.exitReasonFinishedHint,
      ),
      (
        ExitReason.emergency,
        Icons.emergency_outlined,
        l10n.exitReasonEmergency,
        l10n.exitReasonEmergencyHint,
      ),
      (
        ExitReason.stuck,
        Icons.psychology_alt_outlined,
        l10n.exitReasonStuck,
        l10n.exitReasonStuckHint,
      ),
      (
        ExitReason.tired,
        Icons.nightlight_outlined,
        l10n.exitReasonTired,
        l10n.exitReasonTiredHint,
      ),
      (
        ExitReason.needApp,
        Icons.apps_outlined,
        l10n.exitReasonNeedApp,
        l10n.exitReasonNeedAppHint,
      ),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FokusRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            FokusSpacing.lg,
            FokusSpacing.lg,
            FokusSpacing.lg,
            FokusSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.exitSheetTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: FokusSpacing.xxs),
              Text(
                l10n.exitSheetSubtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: FokusSpacing.md),
              for (final (reason, icon, label, hint) in options)
                _ReasonRow(
                  icon: icon,
                  label: label,
                  hint: hint,
                  onTap: () => onPick(reason),
                ),
              const SizedBox(height: FokusSpacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(FokusSpacing.minTouchTarget),
                ),
                onPressed: onStay,
                child: Text(l10n.exitStayInFocus),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label. $hint',
      child: InkWell(
        borderRadius: BorderRadius.circular(FokusRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FokusSpacing.xs,
            vertical: FokusSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: FokusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Honest consequences before a strict-mode abort (spec §3.4): plain facts,
/// no red-scary styling, "Keep going" is the primary action, and no time
/// pressure. When lock-break tokens exist, the graceful redemption offer
/// renders here.
class _StrictConsequences extends ConsumerWidget {
  const _StrictConsequences({
    required this.onEndAnyway,
    required this.onKeepGoing,
    required this.onRedeemToken,
  });

  final VoidCallback onEndAnyway;
  final VoidCallback onKeepGoing;
  final VoidCallback onRedeemToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // 0 while unredeemable (no token or weekly cap — spec §3.5). Tokens are
    // earned by streak milestones (F-09), so pre-streak users never see it.
    final offerTokens = ref.watch(lockBreakOfferProvider).value ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FokusSpacing.lg),
        child: Card(
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FokusRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(FokusSpacing.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.exitConfirmTitle,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: FokusSpacing.sm),
                Text(
                  l10n.exitConfirmBody,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (offerTokens > 0) ...[
                  const SizedBox(height: FokusSpacing.md),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(FokusSpacing.minTouchTarget),
                    ),
                    icon: const Text('🎟'),
                    onPressed: onRedeemToken,
                    label: Text(
                      l10n.exitTokenOffer(offerTokens),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: FokusSpacing.lg),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(FokusSpacing.minTouchTarget),
                  ),
                  onPressed: onKeepGoing,
                  child: Text(l10n.exitConfirmKeepGoing),
                ),
                const SizedBox(height: FokusSpacing.xs),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(FokusSpacing.minTouchTarget),
                  ),
                  onPressed: onEndAnyway,
                  child: Text(l10n.exitConfirmEnd),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
