import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/stats/presentation/stats_screen.dart';
import 'package:fokus/l10n/generated/app_localizations.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

/// F-09 done-criterion: the today view shows the four §3.6 stats.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('today view renders the four MVP stats', (tester) async {
    final db = testDb();
    final fake = FakeBlockingAdapter();
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
    final id = await sessions.createSession(
      plannedMin: 25,
      strictMode: false,
      startTime: now.subtract(const Duration(minutes: 25)),
    );
    await sessions.completeSession(
      id,
      reason: CompletionReason.timerEnd,
      actualMin: 25,
      endTime: now,
    );
    await container.read(distractionRepositoryProvider).logAttempt(
          sessionId: id,
          packageName: 'com.tiktok',
          ts: now.subtract(const Duration(minutes: 10)),
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Focus minutes'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('Distractions blocked'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Most intercepted'), findsOneWidget);
    expect(find.text('com.tiktok'), findsOneWidget); // no appName mapped
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
  });
}
