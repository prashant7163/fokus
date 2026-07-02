import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/dash_calculator.dart';
import '../application/dash_providers.dart';
import 'dash_bar_chart.dart';

/// The F-14 day/week/month dashboard (fokus-specs §3.6): weekly focus score
/// ("beta"), segmented range control, and hand-rolled charts for focus time,
/// sessions completed vs ended early, distraction count, and the recovery
/// resume-rate. Renders below the F-09 today view on [StatsScreen].
class DashSection extends ConsumerStatefulWidget {
  const DashSection({super.key});

  @override
  ConsumerState<DashSection> createState() => _DashSectionState();
}

class _DashSectionState extends ConsumerState<DashSection> {
  DashRange _range = DashRange.week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final data = ref.watch(dashDataProvider(_range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: FokusSpacing.sectionGap),
        Text(l10n.dashTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: FokusSpacing.md),
        const _FocusScoreCard(),
        const SizedBox(height: FokusSpacing.md),
        Semantics(
          label: l10n.dashRangeSemantics,
          container: true,
          child: SegmentedButton<DashRange>(
            segments: [
              ButtonSegment(
                value: DashRange.day,
                label: Text(l10n.dashRangeDay),
              ),
              ButtonSegment(
                value: DashRange.week,
                label: Text(l10n.dashRangeWeek),
              ),
              ButtonSegment(
                value: DashRange.month,
                label: Text(l10n.dashRangeMonth),
              ),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: FokusSpacing.md),
        data.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(FokusSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (d) => _Charts(data: d),
        ),
      ],
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({required this.data});

  final DashData data;

  /// Sparse x labels: hours 0/6/12/18 for day, every weekday for week,
  /// days 1/8/15/22/last for month.
  List<String> _xLabels(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final starts = data.window.bucketStarts;
    switch (data.window.range) {
      case DashRange.day:
        return [
          for (final t in starts) t.hour % 6 == 0 ? '${t.hour}' : '',
        ];
      case DashRange.week:
        final fmt = DateFormat.E(locale);
        return [for (final t in starts) fmt.format(t)];
      case DashRange.month:
        final last = starts.length;
        return [
          for (final t in starts)
            (t.day % 7 == 1 || t.day == last) ? '${t.day}' : '',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final xLabels = _xLabels(context);
    final buckets = data.buckets;

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: FokusSpacing.lg),
        child: Center(
          child: Text(
            l10n.dashNoData,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: l10n.dashFocusTime,
          chart: DashBarChart(
            values: [for (final b in buckets) b.focusMinutes.toDouble()],
            xLabels: xLabels,
            color: theme.colorScheme.primary,
            semanticsLabel:
                l10n.dashFocusTimeSemantics(data.totalFocusMinutes),
            maxTickLabel: (m) => l10n.statsMinutesValue(m),
          ),
        ),
        const SizedBox(height: FokusSpacing.sm),
        _ChartCard(
          title: l10n.dashSessions,
          legend: Row(
            children: [
              DashLegendEntry(
                color: theme.colorScheme.primary,
                label: l10n.dashCompleted,
              ),
              const SizedBox(width: FokusSpacing.md),
              DashLegendEntry(
                color: theme.colorScheme.outline,
                label: l10n.dashEndedEarly,
              ),
            ],
          ),
          chart: DashBarChart(
            values: [for (final b in buckets) b.completed.toDouble()],
            stackedValues: [
              for (final b in buckets) b.endedEarly.toDouble(),
            ],
            xLabels: xLabels,
            color: theme.colorScheme.primary,
            stackedColor: theme.colorScheme.outline,
            semanticsLabel: l10n.dashSessionsSemantics(
              data.totalCompleted,
              data.totalEndedEarly,
            ),
            maxTickLabel: (m) => '$m',
          ),
        ),
        const SizedBox(height: FokusSpacing.sm),
        _ChartCard(
          title: l10n.dashDistractions,
          chart: DashBarChart(
            values: [for (final b in buckets) b.distractions.toDouble()],
            xLabels: xLabels,
            color: theme.colorScheme.secondary,
            semanticsLabel:
                l10n.dashDistractionsSemantics(data.totalDistractions),
            maxTickLabel: (m) => '$m',
          ),
        ),
        const SizedBox(height: FokusSpacing.sm),
        _ResumeRateCard(data: data),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.chart, this.legend});

  final String title;
  final Widget chart;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (legend != null) ...[
              const SizedBox(height: FokusSpacing.xs),
              legend!,
            ],
            const SizedBox(height: FokusSpacing.sm),
            chart,
          ],
        ),
      ),
    );
  }
}

/// Single-ratio form: a meter, not a chart (resume-rate over the range).
/// Track = [FokusColors.ringTrack] (lighter step of the fill's own family).
class _ResumeRateCard extends StatelessWidget {
  const _ResumeRateCard({required this.data});

  final DashData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fokus = theme.extension<FokusColors>()!;
    final rate = data.resumeRate;
    final samples = data.recoveriesResumed + data.recoveriesExited;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.dashResumeRate, style: theme.textTheme.titleSmall),
                if (rate != null)
                  Text(
                    l10n.dashPercent((rate * 100).round()),
                    style: theme.textTheme.titleSmall,
                  ),
              ],
            ),
            const SizedBox(height: FokusSpacing.sm),
            if (rate == null)
              Text(
                l10n.dashResumeRateEmpty,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else ...[
              ExcludeSemantics(
                // The row above + detail line below carry the value.
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: fokus.ringTrack,
                    borderRadius: BorderRadius.circular(FokusRadius.full),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: rate,
                    heightFactor: 1,
                    child: ColoredBox(color: theme.colorScheme.secondary),
                  ),
                ),
              ),
              const SizedBox(height: FokusSpacing.xs),
              Text(
                l10n.dashResumeRateDetail(data.recoveriesResumed, samples),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FocusScoreCard extends ConsumerWidget {
  const _FocusScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final score = ref.watch(focusScoreProvider);

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FokusRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FokusSpacing.cardPadding),
        child: score.when(
          loading: () => const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.dashFocusScore, style: theme.textTheme.titleSmall),
                  const SizedBox(width: FokusSpacing.xs),
                  // Spec §3.6: the v1 formula MUST be labeled beta in the UI.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FokusSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(FokusRadius.xs),
                    ),
                    child: Text(
                      l10n.dashBetaTag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FokusSpacing.sm),
              if (s == null)
                Text(
                  l10n.dashFocusScoreEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                Semantics(
                  label: l10n.dashFocusScoreSemantics(s.score),
                  container: true,
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${s.score}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: FokusSpacing.xs),
                        Text(
                          l10n.dashScoreOutOf,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: FokusSpacing.sm),
                _ScoreComponentRow(
                  label: l10n.dashScoreCompletion,
                  value: s.completionRate,
                ),
                if (s.volumeVsBaseline != null)
                  _ScoreComponentRow(
                    label: l10n.dashScoreVolume,
                    value: s.volumeVsBaseline!,
                  ),
                if (s.resumeRate != null)
                  _ScoreComponentRow(
                    label: l10n.dashScoreRecovery,
                    value: s.resumeRate!,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreComponentRow extends StatelessWidget {
  const _ScoreComponentRow({required this.label, required this.value});

  final String label;

  /// 0–1.
  final double value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(top: FokusSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: muted),
          Text(l10n.dashPercent((value * 100).round()), style: muted),
        ],
      ),
    );
  }
}
