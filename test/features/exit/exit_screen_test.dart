import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/data/repositories/session_repository.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/exit/presentation/exit_screen.dart';
import 'package:fokus/features/session/presentation/session_complete_screen.dart';
import 'package:fokus/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

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

  SessionController session() =>
      container.read(sessionControllerProvider.notifier);
  SessionState state() => container.read(sessionControllerProvider);
  SessionRepository sessions() => container.read(sessionRepositoryProvider);

  Future<String> startSession({bool strictMode = false}) async {
    await session().start(
      plannedMin: 30,
      taskAnchor: 'write',
      strictMode: strictMode,
    );
    return state().sessionId!;
  }

  /// Pumps `/exit` (optionally with a confirm reason) inside a minimal
  /// GoRouter. Stub routes echo their query params so navigation targets are
  /// assertable from the rendered text.
  Future<GoRouter> pumpExit(
    WidgetTester tester, {
    String? confirm,
  }) async {
    final router = GoRouter(
      initialLocation: confirm == null ? '/exit' : '/exit?confirm=$confirm',
      routes: [
        GoRoute(
          path: '/exit',
          builder: (c, s) => ExitScreen(
            confirmReasonName: s.uri.queryParameters['confirm'],
          ),
        ),
        GoRoute(
          path: '/recovery',
          builder: (c, s) => _Stub(
            'recovery'
            ':${s.uri.queryParameters['module'] ?? '-'}'
            ':${s.uri.queryParameters['exitReason'] ?? '-'}',
          ),
        ),
        GoRoute(path: '/session', builder: (c, s) => const _Stub('session')),
        GoRoute(
          path: '/session-complete',
          builder: (c, s) => const SessionCompleteScreen(),
        ),
        GoRoute(path: '/', builder: (c, s) => const _Stub('home')),
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
    await tester.pump();
    return router;
  }

  /// Async handlers persist + navigate; a few bounded pumps settle them.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('reason sheet', () {
    testWidgets('finished task completes the session and counts as done',
        (tester) async {
      final id = await startSession();
      await pumpExit(tester);

      await tester.tap(find.text('Finished my task'));
      await settle(tester);

      expect(state().status, SessionStatus.completed);
      expect(state().completionReason, CompletionReason.finishedTask);
      final row = await sessions().getById(id);
      expect(row!.status, SessionStatus.completed);
      expect(row.completionReason, CompletionReason.finishedTask);
      expect(row.exitReason, ExitReason.finishedTask);
      // Celebration, not a guilt-free void: the complete screen (F-09).
      expect(find.text("Task done — that's what counts."), findsOneWidget);
    });

    testWidgets('emergency exits immediately — even in strict mode, no dialog',
        (tester) async {
      final id = await startSession(strictMode: true);
      await pumpExit(tester);

      await tester.tap(find.text('Emergency'));
      await settle(tester);

      // Straight out: no consequence step, no denial, 2nd tap left.
      expect(state().status, SessionStatus.aborted);
      expect((await sessions().getById(id))!.exitReason, ExitReason.emergency);
      expect(find.text('stub:home'), findsOneWidget);
      expect(find.text('Session ended.'), findsOneWidget);
    });

    testWidgets('stuck records the reason and routes to the recovery hub',
        (tester) async {
      final id = await startSession();
      await pumpExit(tester);

      await tester.tap(find.text("I'm stuck"));
      await settle(tester);

      expect(find.text('stub:recovery:-:stuck'), findsOneWidget);
      expect((await sessions().getById(id))!.exitReason, ExitReason.stuck);
      // The session is not ended by choosing to try recovery.
      expect(state().isRunning, isTrue);
    });

    testWidgets('tired preselects Breathe', (tester) async {
      final id = await startSession();
      await pumpExit(tester);

      await tester.tap(find.text("I'm tired"));
      await settle(tester);

      expect(find.text('stub:recovery:breathe:tired'), findsOneWidget);
      expect((await sessions().getById(id))!.exitReason, ExitReason.tired);
    });

    testWidgets('stay in focus returns to the session, nothing recorded',
        (tester) async {
      final id = await startSession();
      await pumpExit(tester);

      await tester.tap(find.text('Stay in focus'));
      await settle(tester);

      expect(find.text('stub:session'), findsOneWidget);
      expect(state().status, SessionStatus.active);
      expect((await sessions().getById(id))!.exitReason, isNull);
    });

    testWidgets('without a running session it redirects home', (tester) async {
      await pumpExit(tester);
      await settle(tester);
      expect(find.text('stub:home'), findsOneWidget);
    });

    testWidgets(
        'cold-start deep link: a session only in the DB still shows the sheet',
        (tester) async {
      // The intercept's emergency-exit deep link boots the engine cold: the
      // session exists in the DB but hydration is async — the transient idle
      // must not bounce home (M2 emulator finding).
      await sessions().createSession(plannedMin: 30, strictMode: false);
      await pumpExit(tester);
      await settle(tester);

      expect(find.text('Why are you leaving?'), findsOneWidget);
      expect(find.text('stub:home'), findsNothing);
      expect(state().isRunning, isTrue); // hydrated from the DB row
    });
  });

  group('need one app', () {
    testWidgets('non-strict: picker grants a 5-min pass, timer keeps running',
        (tester) async {
      final id = await startSession();
      await container.read(appListsRepositoryProvider).addBlockedApp(
            packageName: 'com.spotify.music',
            appName: 'Spotify',
          );
      await pumpExit(tester);

      await tester.tap(find.text('I need one app'));
      await settle(tester);
      expect(find.text('Which app do you need?'), findsOneWidget);

      await tester.tap(find.text('Spotify'));
      await settle(tester);

      final granted = fake.grantedPasses.single;
      expect(granted.packageName, 'com.spotify.music');
      expect(
        granted.endEpochMs,
        now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      expect(state().status, SessionStatus.active); // never a pause (D-011)
      expect(state().passPackage, 'com.spotify.music');
      expect((await sessions().getById(id))!.exitReason, ExitReason.needApp);
      expect(
        find.text("5-minute pass — Spotify. Timer's still running."),
        findsOneWidget,
      );
      expect(find.text('stub:session'), findsOneWidget);
    });

    testWidgets('strict: denied kindly, recovery offered, no pass granted',
        (tester) async {
      final id = await startSession(strictMode: true);
      await pumpExit(tester);

      await tester.tap(find.text('I need one app'));
      await settle(tester);

      expect(find.text('Strict mode is on'), findsOneWidget);
      expect(fake.grantedPasses, isEmpty);
      expect(state().isRunning, isTrue);
      expect((await sessions().getById(id))!.exitReason, ExitReason.needApp);

      await tester.tap(find.text('Try a recovery instead'));
      await settle(tester);
      expect(find.text('stub:recovery:-:needApp'), findsOneWidget);
    });

    testWidgets('strict denial "Back to focus" stays in the session',
        (tester) async {
      await startSession(strictMode: true);
      await pumpExit(tester);

      await tester.tap(find.text('I need one app'));
      await settle(tester);
      await tester.tap(find.text('Back to focus'));
      await settle(tester);

      expect(find.text('stub:session'), findsOneWidget);
      expect(state().status, SessionStatus.active);
      expect(fake.grantedPasses, isEmpty);
    });
  });

  group('confirm-abort (recovery hand-back)', () {
    testWidgets('non-strict aborts immediately with the given reason',
        (tester) async {
      final id = await startSession();
      await pumpExit(tester, confirm: 'stuck');
      await settle(tester);

      expect(state().status, SessionStatus.aborted);
      expect((await sessions().getById(id))!.exitReason, ExitReason.stuck);
      expect(find.text('stub:home'), findsOneWidget);
      expect(find.text('Session ended.'), findsOneWidget);
    });

    testWidgets('strict shows honest consequences; End anyway aborts',
        (tester) async {
      final id = await startSession(strictMode: true);
      await pumpExit(tester, confirm: 'tired');
      await settle(tester);

      expect(find.text('End this session early?'), findsOneWidget);
      expect(state().isRunning, isTrue); // nothing ended yet

      await tester.tap(find.text('End anyway'));
      await settle(tester);

      expect(state().status, SessionStatus.aborted);
      expect((await sessions().getById(id))!.exitReason, ExitReason.tired);
      expect(find.text('stub:home'), findsOneWidget);
    });

    testWidgets(
        'strict with a token: graceful lock-break offer completes via '
        'lockBreak and celebrates', (tester) async {
      await container
          .read(streakRepositoryProvider)
          .updateSummary(tokensAvailable: 2, tokensLifetime: 2);
      final id = await startSession(strictMode: true);
      await pumpExit(tester, confirm: 'stuck');
      await settle(tester);

      expect(find.textContaining('lock-break token'), findsOneWidget);
      await tester.tap(find.textContaining('lock-break token'));
      await settle(tester);

      expect(state().status, SessionStatus.completed);
      expect(state().completionReason, CompletionReason.lockBreak);
      final row = await sessions().getById(id);
      expect(row!.completionReason, CompletionReason.lockBreak);
      expect(
        (await container.read(streakRepositoryProvider).getSummary())
            .tokensAvailable,
        1,
      );
      // Graceful celebration, streak-safe framing (SCREENS §7).
      expect(
        find.text('Wrapped with a lock-break — streak safe.'),
        findsOneWidget,
      );
    });

    testWidgets('strict Keep going resumes the session', (tester) async {
      await startSession(strictMode: true);
      // Recovery hands back mid-recovery; Keep going must land on active.
      await session().enterRecovery();
      await pumpExit(tester, confirm: 'stuck');
      await settle(tester);

      await tester.tap(find.text('Keep going'));
      await settle(tester);

      expect(find.text('stub:session'), findsOneWidget);
      expect(state().status, SessionStatus.active);
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
