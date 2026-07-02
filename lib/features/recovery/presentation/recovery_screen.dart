import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/recovery_controller.dart';
import 'modules/breathe_module.dart';
import 'modules/shrink_module.dart';
import 'modules/task_reset_module.dart';
import 'widgets/recovery_illustration.dart';
import 'widgets/recovery_module_scaffold.dart';
import 'widgets/timed_reset_body.dart';

/// Recovery flow (F-07, SCREENS §5) — the emotional heart. Entered from the
/// intercept deep link (`/recovery`, optional `?module=` pre-selects) or the
/// exit flow. Either a **hub** (pick one of 5) or a **module** directly.
///
/// Every invocation logs a RecoveryEvent via [RecoveryController] — including
/// abandon (back button), which closes the event as `exited`.
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key, this.preselectedModule});

  /// RecoveryType name from the deep link (`breathe`, `taskReset`, …).
  final String? preselectedModule;

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  RecoveryType? _selected;
  final _taskNextStep = TextEditingController();
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    final pre = _parse(widget.preselectedModule);
    if (pre != null) {
      _selected = pre;
      // Begin after first frame so the provider + context are ready.
      WidgetsBinding.instance.addPostFrameCallback((_) => _begin(pre));
    }
  }

  @override
  void dispose() {
    _taskNextStep.dispose();
    super.dispose();
  }

  RecoveryType? _parse(String? name) {
    if (name == null) return null;
    for (final t in RecoveryType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  RecoveryController get _controller =>
      ref.read(recoveryControllerProvider);

  Future<void> _begin(RecoveryType type) => _controller.begin(type);

  void _selectModule(RecoveryType type) {
    setState(() => _selected = type);
    _begin(type);
  }

  // --- resolution paths (each closes the RecoveryEvent exactly once) -------

  Future<void> _resume({bool showNoted = false}) async {
    if (_resolving) return;
    _resolving = true;
    await _controller.resume();
    if (!mounted) return;
    if (showNoted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).recoveryTaskResetSaved)),
      );
    }
    _goToSession();
  }

  Future<void> _end() async {
    if (_resolving) return;
    _resolving = true;
    await _controller.end();
    if (!mounted) return;
    // Routes toward the exit flow (F-08 owns the reason picker; the session is
    // already aborting via the controller with ExitReason.stuck default).
    context.go(AppRoutes.exit);
  }

  Future<void> _shrink() async {
    if (_resolving) return;
    _resolving = true;
    await ref.read(sessionControllerProvider.notifier).shrinkTo();
    // Shrinking keeps the session running → the recovery result is `resumed`.
    await _controller.resume();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).recoveryShrinkApplied)),
    );
    _goToSession();
  }

  void _goToSession() {
    if (ref.read(sessionControllerProvider).isRunning) {
      context.go(AppRoutes.session);
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Back / dismiss without choosing = abandon (logged as `exited`).
  Future<void> _abandon() async {
    if (_resolving) return;
    _resolving = true;
    await _controller.abandon();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the autoDispose controller alive for the screen's lifetime so every
    // _controller (ref.read) call returns the same event-tracking instance.
    ref.watch(recoveryControllerProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _abandon();
        if (mounted) _goToSession();
      },
      child: _selected == null ? _buildHub(context) : _buildModule(context),
    );
  }

  // --- hub -----------------------------------------------------------------

  Widget _buildHub(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;

    final modules = <_ModuleCardData>[
      _ModuleCardData(RecoveryType.breathe, 'recovery_breathe',
          l10n.recoveryBreatheName, l10n.recoveryBreatheBenefit),
      _ModuleCardData(RecoveryType.taskReset, 'recovery_taskreset',
          l10n.recoveryTaskResetName, l10n.recoveryTaskResetBenefit),
      _ModuleCardData(RecoveryType.stretch, 'recovery_stretch',
          l10n.recoveryStretchName, l10n.recoveryStretchBenefit),
      _ModuleCardData(RecoveryType.water, 'recovery_water',
          l10n.recoveryWaterName, l10n.recoveryWaterBenefit),
      _ModuleCardData(RecoveryType.changeDuration, 'recovery_shrink',
          l10n.recoveryShrinkName, l10n.recoveryShrinkBenefit),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: fokus.calmWash),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: FokusSpacing.lg,
              vertical: FokusSpacing.xl,
            ),
            children: [
              Text(l10n.recoveryHubTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: FokusSpacing.xs),
              Text(
                l10n.recoveryHubSubtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: FokusSpacing.xl),
              for (final m in modules) ...[
                _ModuleCard(data: m, onTap: () => _selectModule(m.type)),
                const SizedBox(height: FokusSpacing.md),
              ],
              const SizedBox(height: FokusSpacing.xs),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await _abandon();
                    if (mounted) _goToSession();
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      FokusSpacing.minTouchTarget,
                      FokusSpacing.minTouchTarget,
                    ),
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Text(l10n.recoverySkip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- module host ---------------------------------------------------------

  Widget _buildModule(BuildContext context) {
    final type = _selected!;
    final l10n = AppLocalizations.of(context);

    // Shrink owns its own CTAs (no shared footer).
    if (type == RecoveryType.changeDuration) {
      return RecoveryModuleScaffold(
        showFooter: false,
        onClose: () async {
          await _abandon();
          if (mounted) _goToSession();
        },
        child: ShrinkModule(onShrink: _shrink, onKeep: _resume),
      );
    }

    final Widget body;
    final bool taskReset = type == RecoveryType.taskReset;
    switch (type) {
      case RecoveryType.breathe:
        body = BreatheModule(onCompleted: () {/* footer takes over */});
      case RecoveryType.taskReset:
        body = TaskResetModule(
          controller: _taskNextStep,
        );
      case RecoveryType.stretch:
        body = TimedResetBody(
          illustrationAsset: 'recovery_stretch',
          prompt: l10n.recoveryStretchPrompt,
          earlyCompleteLabel: l10n.recoveryStretchDone,
          onFinished: () {/* footer takes over */},
        );
      case RecoveryType.water:
        body = TimedResetBody(
          illustrationAsset: 'recovery_water',
          prompt: l10n.recoveryWaterPrompt,
          earlyCompleteLabel: l10n.recoveryWaterDone,
          onFinished: () {/* footer takes over */},
        );
      case RecoveryType.changeDuration:
        body = const SizedBox.shrink(); // handled above.
    }

    return RecoveryModuleScaffold(
      onClose: () async {
        await _abandon();
        if (mounted) _goToSession();
      },
      onResume: () => _resume(showNoted: taskReset),
      onEnd: _end,
      child: body,
    );
  }
}

class _ModuleCardData {
  const _ModuleCardData(this.type, this.asset, this.name, this.benefit);
  final RecoveryType type;
  final String asset;
  final String name;
  final String benefit;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.data, required this.onTap});

  final _ModuleCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${data.name}. ${data.benefit}',
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FokusRadius.lg),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(FokusRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(FokusSpacing.md),
            child: Row(
              children: [
                RecoveryIllustration(asset: data.asset, size: 56),
                const SizedBox(width: FokusSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: FokusSpacing.xxs),
                      Text(
                        data.benefit,
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
      ),
    );
  }
}
