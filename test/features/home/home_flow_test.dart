import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/home/presentation/home_screen.dart';
import 'package:fokus/features/session/presentation/session_config_screen.dart';
import 'package:fokus/features/session/presentation/session_screen.dart';
import 'package:fokus/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

/// F-11: home dashboard, start-session config, active session. The done
/// criterion — one-tap repeat of the last config — is the first test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FokusDatabase db;
  late FakeBlockingAdapter fake;
  late ProviderContainer container;
  late DateTime now;
  final t0 = DateTime(2026, 7, 2, 9, 0);

  setUp(() {
    now = t0;
    db = testDb();
    fake = FakeBlockingAdapter();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      blockingAdapterProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => now),
      tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await fake.dispose();
    await db.close();
  });

  SessionState state() => container.read(sessionControllerProvider);

  Future<GoRouter> pump(WidgetTester tester, {String at = '/'}) async {
    final router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
        GoRoute(
          path: '/new-session',
          builder: (c, s) => const SessionConfigScreen(),
        ),
        GoRoute(path: '/session', builder: (c, s) => const SessionScreen()),
        GoRoute(
          path: '/session-complete',
          builder: (c, s) => const _Stub('complete'),
        ),
        GoRoute(path: '/exit', builder: (c, s) => const _Stub('exit')),
        GoRoute(path: '/stats', builder: (c, s) => const _Stub('stats')),
        GoRoute(path: '/settings', builder: (c, s) => const _Stub('settings')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('de')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> seedLastSession({
    int plannedMin = 45,
    bool strictMode = false,
  }) async {
    final sessions = container.read(sessionRepositoryProvider);
    final id = await sessions.createSession(
      plannedMin: plannedMin,
      strictMode: strictMode,
      taskAnchor: 'write thesis',
      startTime: t0.subtract(const Duration(hours: 2)),
    );
    await sessions.completeSession(
      id,
      reason: CompletionReason.timerEnd,
      actualMin: plannedMin,
      endTime: t0.subtract(const Duration(hours: 1)),
    );
    await container.read(appListsRepositoryProvider).addBlockedApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
        );
  }

  group('home', () {
    testWidgets(
        'one-tap repeat: single tap starts the last config and lands on the '
        'running session (SACRED — no confirm)', (tester) async {
      await seedLastSession(plannedMin: 45, strictMode: true);
      await pump(tester);
      await settle(tester);

      expect(find.text('Pick up where you left off'), findsOneWidget);
      await tester.tap(find.text('Start focus — 45 min'));
      await settle(tester);

      // ONE tap → session active with the exact last config.
      expect(state().status, SessionStatus.active);
      expect(state().plannedMin, 45);
      expect(state().strictMode, isTrue);
      expect(state().taskAnchor, 'write thesis');
      // …and we are looking at the running session.
      expect(find.text('Session'), findsOneWidget);
      expect(find.text('45:00'), findsOneWidget);
    });

    testWidgets('first run shows the friendly first-session hero',
        (tester) async {
      await pump(tester);
      await settle(tester);
      expect(find.text('Your focus starts here'), findsOneWidget);
      expect(find.text('Start your first session'), findsWidgets);
    });

    testWidgets('running session replaces the hero with a resume card',
        (tester) async {
      await seedLastSession();
      await container
          .read(sessionControllerProvider.notifier)
          .start(plannedMin: 30);
      await pump(tester);
      await settle(tester);

      expect(find.textContaining('In focus'), findsOneWidget);
      await tester.tap(find.text('Back to session'));
      await settle(tester);
      expect(find.text('30:00'), findsOneWidget);
    });

    testWidgets('degraded permissions surface the honest banner',
        (tester) async {
      fake.permissionMap = {
        for (final k in fake.permissionMap.keys) k: false,
      };
      await pump(tester);
      await settle(tester);
      expect(
        find.text('Blocking is paused — accessibility off'),
        findsOneWidget,
      );
    });
  });

  group('config', () {
    testWidgets('start uses chips, anchor and strict switch', (tester) async {
      await pump(tester, at: '/new-session');
      await settle(tester);

      await tester.tap(find.text('60'));
      await tester.enterText(
        find.byType(TextField).first,
        'deep work block',
      );
      await tester.tap(find.text('Strict mode'));
      await settle(tester);
      await tester.tap(find.text('Start focus'));
      await settle(tester);

      expect(state().status, SessionStatus.active);
      expect(state().plannedMin, 60);
      expect(state().taskAnchor, 'deep work block');
      expect(state().strictMode, isTrue);
    });

    testWidgets('no apps selected shows the honest timer-only hint',
        (tester) async {
      await pump(tester, at: '/new-session');
      await settle(tester);
      expect(
        find.text('No apps selected — this will be a timer-only session.'),
        findsOneWidget,
      );
    });
  });

  group('active session', () {
    testWidgets('renders countdown, anchor, caption; End goes to exit flow',
        (tester) async {
      await seedLastSession();
      await container.read(sessionControllerProvider.notifier).start(
            plannedMin: 30,
            taskAnchor: 'write the intro',
          );
      await pump(tester, at: '/session');
      await settle(tester);

      expect(find.text('30:00'), findsOneWidget);
      expect(find.text('write the intro'), findsOneWidget);
      expect(find.text('Blocked while you focus'), findsOneWidget);

      await tester.tap(find.text('End session'));
      await settle(tester);
      expect(find.text('stub:exit'), findsOneWidget);
    });

    testWidgets('timer end auto-transitions to the celebration',
        (tester) async {
      await container
          .read(sessionControllerProvider.notifier)
          .start(plannedMin: 30);
      await pump(tester, at: '/session');
      await settle(tester);

      now = t0.add(const Duration(minutes: 30, seconds: 1));
      await container.read(sessionControllerProvider.notifier).syncWithClock();
      await settle(tester);

      expect(state().status, SessionStatus.completed);
      expect(find.text('stub:complete'), findsOneWidget);
    });

    testWidgets('without a session it redirects home', (tester) async {
      await pump(tester, at: '/session');
      await settle(tester);
      expect(find.text('FOKUS'), findsOneWidget); // home app bar
    });
  });
}

class _Stub extends StatelessWidget {
  const _Stub(this.name);
  final String name;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('stub:$name')));
}
