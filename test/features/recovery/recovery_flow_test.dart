import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/data/repositories/recovery_repository.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/recovery/presentation/recovery_screen.dart';
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
  RecoveryRepository recoveryRepo() =>
      container.read(recoveryRepositoryProvider);

  Future<String> startSession({int plannedMin = 30}) async {
    await session().start(plannedMin: plannedMin, taskAnchor: 'write');
    return container.read(sessionControllerProvider).sessionId!;
  }

  /// Pumps the recovery screen inside a minimal GoRouter so context.go works.
  Future<GoRouter> pumpRecovery(
    WidgetTester tester, {
    String? module,
    String? exitReason,
  }) async {
    final query = [
      if (module != null) 'module=$module',
      if (exitReason != null) 'exitReason=$exitReason',
    ].join('&');
    final router = GoRouter(
      initialLocation: query.isEmpty ? '/recovery' : '/recovery?$query',
      routes: [
        GoRoute(
          path: '/recovery',
          builder: (c, s) => RecoveryScreen(
            preselectedModule: s.uri.queryParameters['module'],
            exitReasonName: s.uri.queryParameters['exitReason'],
          ),
        ),
        GoRoute(path: '/session', builder: (c, s) => const _Stub('session')),
        GoRoute(
          path: '/exit',
          builder: (c, s) =>
              _Stub('exit:${s.uri.queryParameters['confirm'] ?? '-'}'),
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
    // Two pumps rather than pumpAndSettle: the breathe/timed modules run
    // repeating animations that would trap pumpAndSettle. Two frames are
    // enough to build the screen and run the post-frame _begin().
    await tester.pump();
    await tester.pump();
    return router;
  }

  group('RecoveryEvent persistence', () {
    testWidgets('entering a module writes a start row; resume closes resumed',
        (tester) async {
      final id = await startSession();
      await pumpRecovery(tester, module: 'stretch');
      // Let the post-frame _begin() (enterRecovery + startEvent) resolve.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Start row exists, still open.
      var events = await recoveryRepo().eventsForSession(id);
      expect(events, hasLength(1));
      expect(events.single.type, RecoveryType.stretch);
      expect(events.single.result, isNull);

      // Complete the timed body early, then Resume focus.
      await tester.tap(find.text("I've stretched"));
      await tester.pump();
      await tester.tap(find.text('Resume focus'));
      await tester.pump();
      await tester.pump();

      events = await recoveryRepo().eventsForSession(id);
      expect(events.single.result, RecoveryResult.resumed);
      expect(events.single.completedAt, isNotNull);
      // Session is back to active.
      expect(container.read(sessionControllerProvider).status,
          SessionStatus.active);
    });

    testWidgets(
        'End session closes the event as exited and hands off to the exit flow',
        (tester) async {
      final id = await startSession();
      await pumpRecovery(tester, module: 'water');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // The water body can overflow the 600px test surface — scrolled out of
      // view, the button's center lands on the footer and taps "Resume focus".
      await tester.ensureVisible(find.text("I'm back"));
      await tester.pump();
      await tester.tap(find.text("I'm back"));
      await tester.pump();
      await tester.tap(find.text('End session'));
      await tester.pump();
      await tester.pump();

      final events = await recoveryRepo().eventsForSession(id);
      expect(events.single.result, RecoveryResult.exited);
      // The session is NOT ended here — the exit flow (F-08) owns its fate.
      // First-visit entry → the reason sheet (no confirm param).
      expect(find.text('stub:exit:-'), findsOneWidget);
      expect(container.read(sessionControllerProvider).status,
          SessionStatus.recoveryInProgress);
      expect(container.read(sessionControllerProvider).exitReason, isNull);
    });

    testWidgets(
        'End session from an exit-entered recovery confirms the given reason',
        (tester) async {
      final id = await startSession();
      await pumpRecovery(tester, module: 'breathe', exitReason: 'tired');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.ensureVisible(find.text('End session'));
      await tester.pump();
      await tester.tap(find.text('End session'));
      await tester.pump();
      await tester.pump();

      final events = await recoveryRepo().eventsForSession(id);
      expect(events.single.result, RecoveryResult.exited);
      // No re-asking (FLOWS §4): straight to confirm-abort with `tired`.
      expect(find.text('stub:exit:tired'), findsOneWidget);
    });

    testWidgets('abandon (back button) writes the event as exited',
        (tester) async {
      final id = await startSession();
      final router = await pumpRecovery(tester, module: 'breathe');

      // Simulate a system back — pop is intercepted → abandon.
      await router.routerDelegate.popRoute();
      // Bounded pumps (breathe animates; pumpAndSettle would trap).
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final events = await recoveryRepo().eventsForSession(id);
      expect(events, hasLength(1));
      expect(events.single.type, RecoveryType.breathe);
      expect(events.single.result, RecoveryResult.exited); // abandon == exited
    });
  });

  group('module completion', () {
    testWidgets('breathe runs its phases then footer resumes', (t) async {
      final id = await startSession();
      await pumpRecovery(t, module: 'breathe');

      // Phase word is shown (module rendered, cross-fading).
      expect(find.text('Breathe in'), findsWidgets);

      // Advance through 2 cycles (2 × 3 phases × 4s = 24s) in steps so the
      // repeating animation never traps pumpAndSettle.
      for (var i = 0; i < 26; i++) {
        await t.pump(const Duration(seconds: 1));
      }

      // Resume focus closes the event as resumed.
      await t.tap(find.text('Resume focus'));
      await t.pump();
      await t.pump();
      final events = await recoveryRepo().eventsForSession(id);
      expect(events.single.result, RecoveryResult.resumed);
    });

    testWidgets('task reset resumes with a Noted snackbar', (t) async {
      await startSession();
      await pumpRecovery(t, module: 'taskReset');
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      await t.enterText(find.byType(TextField), 'write one sentence');
      await t.tap(find.text('Resume focus'));
      await t.pump(); // start snackbar
      await t.pump();
      expect(find.text('Noted.'), findsOneWidget);
    });

    testWidgets('shrink reduces remaining to 10 min and resumes', (t) async {
      final id = await startSession(plannedMin: 30);
      await pumpRecovery(t, module: 'changeDuration');
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      await t.tap(find.text('Shrink to 10 min'));
      await t.pump();
      await t.pump();

      // Session still running, remaining ~10 min.
      final st = container.read(sessionControllerProvider);
      expect(st.status, SessionStatus.active);
      expect(st.remaining, const Duration(minutes: 10));
      expect(find.text('Session shortened to 10 minutes.'), findsOneWidget);

      final events = await recoveryRepo().eventsForSession(id);
      expect(events.single.type, RecoveryType.changeDuration);
      expect(events.single.result, RecoveryResult.resumed);
    });
  });

  group('hub', () {
    testWidgets('with no preselected module shows 5 module cards', (t) async {
      await startSession();
      await pumpRecovery(t);

      expect(find.text('Breathe'), findsOneWidget);
      expect(find.text('Task reset'), findsOneWidget);
      expect(find.text('Stand & stretch'), findsOneWidget);
      expect(find.text('Water break'), findsOneWidget);
      expect(find.text('Shrink session'), findsOneWidget);
    });

    testWidgets('picking a hub card begins that module', (t) async {
      final id = await startSession();
      await pumpRecovery(t);

      await t.tap(find.text('Stand & stretch'));
      // Bounded pumps: the stretch timer is periodic; _begin runs async.
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      final events = await recoveryRepo().eventsForSession(id);
      expect(events.single.type, RecoveryType.stretch);
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
