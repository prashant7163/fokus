import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/blocking_adapter.dart';
import '../../../core/blocking/providers.dart';
import '../../../core/data/enums.dart';
import '../../../core/data/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/app_icon_row.dart';

/// Active Session (F-11, SCREENS §3): countdown dominant, everything else
/// quiet. The de-emphasized "End session" is the honest exit to the F-08
/// reason flow. Completion auto-transitions to the celebration.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  static const _rotationPeriod = Duration(seconds: 90);

  Timer? _encourageTimer;
  int _encourageIndex = 0;

  @override
  void initState() {
    super.initState();
    _encourageTimer = Timer.periodic(_rotationPeriod, (_) {
      if (mounted) setState(() => _encourageIndex++);
    });
  }

  @override
  void dispose() {
    _encourageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;

    // Terminal transitions route away: completion celebrates, an abort goes
    // home (its toast came from the exit flow).
    ref.listen(sessionControllerProvider, (prev, next) {
      if (prev != null && prev.isRunning) {
        if (next.status == SessionStatus.completed) {
          context.go(AppRoutes.sessionComplete);
        } else if (next.status == SessionStatus.aborted) {
          context.go(AppRoutes.home);
        }
      }
    });
    final session = ref.watch(sessionControllerProvider);

    if (session.status == SessionStatus.failedPermissions) {
      return _FailedPermissionsView(
        onFix: () => ref
            .read(blockingAdapterProvider)
            .requestPermission(PermissionKind.accessibility),
        onHome: () => context.go(AppRoutes.home),
      );
    }
    if (!session.isRunning) {
      // Cold navigation without a session (or post-terminal rebuild while
      // the listener routes) — nothing to show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(sessionControllerProvider).isRunning) {
          context.go(AppRoutes.home);
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final blocked = ref.watch(_sessionBlockedProvider).value ?? const [];
    final icons = ref.watch(blockedAppIconsProvider).value ?? const {};
    final attempts = session.sessionId == null
        ? 0
        : ref.watch(_attemptCountProvider(session.sessionId!)).value ?? 0;

    final remaining = session.remaining.isNegative
        ? Duration.zero
        : session.remaining;
    final total = Duration(minutes: session.plannedMin ?? 1);
    final fraction = total.inSeconds == 0
        ? 0.0
        : 1 - (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final lastMinute = remaining.inSeconds <= 60;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final encouragements = [
      l10n.sessionEncourage1,
      l10n.sessionEncourage2,
      l10n.sessionEncourage3,
      l10n.sessionEncourage4,
      l10n.sessionEncourage5,
    ];
    final encouragement = lastMinute
        ? l10n.sessionAlmostThere
        : encouragements[_encourageIndex % encouragements.length];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FokusSpacing.lg),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.sessionLabel,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (session.strictMode) ...[
                    const SizedBox(width: FokusSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FokusSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(FokusRadius.full),
                      ),
                      child: Text(
                        l10n.homeStrictBadge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Semantics(
                label: l10n.sessionMinutesLeftLabel(remaining.inMinutes),
                child: ExcludeSemantics(
                  child: _CountdownRing(
                    fraction: fraction,
                    remaining: remaining,
                    leftWord: l10n.sessionRemainingLeft,
                    lastMinute: lastMinute,
                    reduceMotion: reduceMotion,
                    gradient: fokus.focusGradient,
                    track: fokus.ringTrack,
                  ),
                ),
              ),
              const SizedBox(height: FokusSpacing.lg),
              if (session.taskAnchor?.isNotEmpty ?? false)
                Text(
                  session.taskAnchor!,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: FokusSpacing.md),
              if (blocked.isNotEmpty) ...[
                AppIconRow(
                  apps: [
                    for (final app in blocked)
                      (packageName: app.packageName, appName: app.appName),
                  ],
                  icons: icons,
                  size: 28,
                ),
                const SizedBox(height: FokusSpacing.xxs),
                Text(
                  l10n.sessionBlockedCaption,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: FokusSpacing.lg),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                child: Text(
                  encouragement,
                  key: ValueKey(encouragement),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.secondary),
                  textAlign: TextAlign.center,
                ),
              ),
              if (session.hasActivePass && session.passEndTime != null) ...[
                const SizedBox(height: FokusSpacing.sm),
                _QuietPill(
                  text: l10n.exitPassChipLabel(
                    _passAppName(blocked, session.passPackage!),
                    _minutesUntil(session.passEndTime!),
                  ),
                ),
              ],
              if (attempts > 0) ...[
                const SizedBox(height: FokusSpacing.sm),
                _QuietPill(text: l10n.sessionRedirects(attempts)),
              ],
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    FokusSpacing.minTouchTarget * 2,
                    FokusSpacing.minTouchTarget,
                  ),
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => context.go(AppRoutes.exit),
                child: Text(l10n.sessionEnd),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _passAppName(List<dynamic> blocked, String pkg) {
    for (final app in blocked) {
      if (app.packageName == pkg) return app.appName as String;
    }
    return pkg;
  }

  int _minutesUntil(DateTime end) {
    final min = end.difference(DateTime.now()).inMinutes;
    return min < 0 ? 0 : min + 1;
  }
}

final _sessionBlockedProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(appListsRepositoryProvider).getBlockedApps(),
);

final _attemptCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, sessionId) =>
      ref.watch(distractionRepositoryProvider).watchCountForSession(sessionId),
);

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.fraction,
    required this.remaining,
    required this.leftWord,
    required this.lastMinute,
    required this.reduceMotion,
    required this.gradient,
    required this.track,
  });

  final double fraction;
  final Duration remaining;
  final String leftWord;
  final bool lastMinute;
  final bool reduceMotion;
  final Gradient gradient;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final text = h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';

    final ring = SizedBox(
      width: 240,
      height: 240,
      child: TweenAnimationBuilder<double>(
        // Interpolating between per-second ticks keeps the sweep continuous;
        // reduced motion snaps per tick (SCREENS §3 a11y).
        tween: Tween(end: fraction),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 1000),
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            gradient: gradient,
            track: track,
            lastMinute: lastMinute,
            amber: theme.extension<FokusColors>()!.streakSignal,
          ),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                leftWord,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
    return ring;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.gradient,
    required this.track,
    required this.lastMinute,
    required this.amber,
  });

  final double progress;
  final Gradient gradient;
  final Color track;
  final bool lastMinute;
  final Color amber;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);

    // Remaining-time arc sweeping toward the top gap (SCREENS §3): what is
    // drawn shrinks as the session progresses.
    final sweep = math.pi * 2 * (1 - progress);
    if (sweep <= 0) return;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = (lastMinute
              ? LinearGradient(colors: [amber, amber])
              : gradient)
          .createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.lastMinute != lastMinute;
}

class _QuietPill extends StatelessWidget {
  const _QuietPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FokusSpacing.sm,
        vertical: FokusSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(FokusRadius.full),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// failedPermissions terminal state (SCREENS §3): desaturated, honest, never
/// silent. The full permissions-health UI is F-12's.
class _FailedPermissionsView extends StatelessWidget {
  const _FailedPermissionsView({required this.onFix, required this.onHome});

  final VoidCallback onFix;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FokusSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(FokusSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(FokusRadius.md),
                ),
                child: Text(
                  l10n.sessionPermissionLost,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ),
              const SizedBox(height: FokusSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(FokusSpacing.minTouchTarget),
                ),
                onPressed: onFix,
                child: Text(l10n.sessionPermissionFix),
              ),
              const SizedBox(height: FokusSpacing.xs),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(FokusSpacing.minTouchTarget),
                ),
                onPressed: onHome,
                child: Text(l10n.sessionGoHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
