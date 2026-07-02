import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/stats/application/dash_calculator.dart';
import 'package:fokus/features/stats/presentation/dash_bar_chart.dart';
import 'package:fokus/features/stats/presentation/stats_screen.dart';
import 'package:fokus/l10n/generated/app_localizations.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

/// F-14 done-criterion: the day/week/month dashboard charts + focus score
/// render below the today view from fixture DB rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard renders charts, resume-rate and beta focus score '
      'from fixture rows', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = testDb();
    final fake = FakeBlockingAdapter();
    // Friday 2026-07-10 → week Mon Jul 6 – Sun Jul 12.
    final now = DateTime(2026, 7, 10, 9, 0);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      blockingAdapterProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => now),
      tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
    ]);
    addTearDown(() async {
      container.dispose();
      await fake.dispose();
      await db.close();
    });

    final sessions = container.read(sessionRepositoryProvider);
    final distractions = container.read(distractionRepositoryProvider);
    final recoveries = container.read(recoveryRepositoryProvider);

    // This week: one completed (25 min, today) …
    final a = await sessions.createSession(
      plannedMin: 25,
      strictMode: false,
      startTime: DateTime(2026, 7, 10, 8),
    );
    await sessions.completeSession(
      a,
      reason: CompletionReason.timerEnd,
      actualMin: 25,
      endTime: DateTime(2026, 7, 10, 8, 25),
    );
    // … one aborted (10 min, Wednesday).
    final b = await sessions.createSession(
      plannedMin: 30,
      strictMode: false,
      startTime: DateTime(2026, 7, 8, 10),
    );
    await sessions.abortSession(
      b,
      exitReason: ExitReason.tired,
      actualMin: 10,
      endTime: DateTime(2026, 7, 8, 10, 10),
    );
    // Baseline: 100 min three weeks back + 40 min on Jul 2 (in July, but
    // before this week) → (100 + 40) / 4 = 35 min/week baseline.
    final c = await sessions.createSession(
      plannedMin: 100,
      strictMode: false,
      startTime: DateTime(2026, 6, 15, 10),
    );
    await sessions.completeSession(
      c,
      reason: CompletionReason.timerEnd,
      actualMin: 100,
      endTime: DateTime(2026, 6, 15, 11, 40),
    );
    final d = await sessions.createSession(
      plannedMin: 40,
      strictMode: false,
      startTime: DateTime(2026, 7, 2, 10),
    );
    await sessions.completeSession(
      d,
      reason: CompletionReason.timerEnd,
      actualMin: 40,
      endTime: DateTime(2026, 7, 2, 10, 40),
    );

    // Distraction attempts: two today, one Wednesday.
    await distractions.logAttempt(
      sessionId: a,
      packageName: 'com.tiktok',
      ts: DateTime(2026, 7, 10, 8, 5),
    );
    await distractions.logAttempt(
      sessionId: a,
      packageName: 'com.tiktok',
      ts: DateTime(2026, 7, 10, 8, 15),
    );
    await distractions.logAttempt(
      sessionId: b,
      packageName: 'com.insta',
      ts: DateTime(2026, 7, 8, 10, 5),
    );

    // Recoveries this week: one resumed, one exited → 50 % resume-rate.
    final r1 = await recoveries.startEvent(
      sessionId: a,
      type: RecoveryType.breathe,
      startedAt: DateTime(2026, 7, 10, 8, 10),
    );
    await recoveries.completeEvent(
      r1,
      result: RecoveryResult.resumed,
      completedAt: DateTime(2026, 7, 10, 8, 12),
    );
    final r2 = await recoveries.startEvent(
      sessionId: b,
      type: RecoveryType.water,
      startedAt: DateTime(2026, 7, 8, 10, 5),
    );
    await recoveries.completeEvent(
      r2,
      result: RecoveryResult.exited,
      completedAt: DateTime(2026, 7, 8, 10, 8),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('de')],
          home: const StatsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Section + segmented control (week is the default).
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(SegmentedButton<DashRange>), findsOneWidget);

    // Focus score card, labeled beta (spec §3.6 mandate):
    // completion 1/2 = 0.5, volume min(1, 35/35) = 1.0, resume-rate 0.5
    // → 100 * (0.25 + 0.30 + 0.10) = 65.
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    expect(find.text('out of 100'), findsOneWidget);

    // The three bucketed charts render from the fixture rows.
    expect(find.text('Focus time'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    // Today tile (F-09) + chart title share this label.
    expect(find.text('Distractions blocked'), findsNWidgets(2));
    expect(find.byType(DashBarChart), findsNWidgets(3));
    expect(find.text('Completed'), findsOneWidget); // legend
    expect(find.text('Ended early'), findsOneWidget);

    // Resume-rate meter with sample counts.
    expect(find.text('Recovery resume rate'), findsOneWidget);
    expect(find.text('1 of 2 recoveries led back to focus'), findsOneWidget);

    // Chart semantics for screen readers (week totals).
    expect(
      find.bySemanticsLabel(
        'Focus time chart. 35 focused minutes in this period.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Sessions chart. 1 completed, 1 ended early.'),
      findsOneWidget,
    );

    // Switch to Day: charts re-bucket (today has data) and still render.
    await tester.tap(find.text('Day'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(DashBarChart), findsNWidgets(3));
    expect(
      find.bySemanticsLabel('Distractions chart. 2 blocked attempts.'),
      findsOneWidget,
    );

    // Switch to Month: July renders too.
    await tester.tap(find.text('Month'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(DashBarChart), findsNWidgets(3));
    expect(
      find.bySemanticsLabel('Sessions chart. 2 completed, 1 ended early.'),
      findsOneWidget,
    );
  });

  testWidgets('empty ranges show the no-data and no-score empty states',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = testDb();
    final fake = FakeBlockingAdapter();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      blockingAdapterProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => DateTime(2026, 7, 10, 9)),
      tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
    ]);
    addTearDown(() async {
      container.dispose();
      await fake.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('de')],
          home: const StatsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('No sessions in this period yet.'), findsOneWidget);
    expect(
      find.text('Finish a session this week to see your first score.'),
      findsOneWidget,
    );
    expect(find.byType(DashBarChart), findsNothing);
  });
}
