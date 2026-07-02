import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/feedback/application/feedback_sampler.dart';
import 'package:fokus/features/session/presentation/session_complete_screen.dart';
import 'package:fokus/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedbackSampler (pure, CONTRACTS §4: 1 in 3)', () {
    test('asks on the 1st, 4th, 7th completion and no others', () {
      final asked = [
        for (var n = 0; n <= 9; n++)
          if (FeedbackSampler.shouldAsk(n)) n,
      ];
      expect(asked, [1, 4, 7]);
    });
  });

  group('feedback row on the complete screen', () {
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

    Future<void> completeFirstSession(WidgetTester tester) async {
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.start(plannedMin: 30, taskAnchor: 'write');
      now = t0.add(const Duration(minutes: 30, seconds: 1));
      await controller.syncWithClock();

      final router = GoRouter(
        initialLocation: '/session-complete',
        routes: [
          GoRoute(
            path: '/session-complete',
            builder: (c, s) => const SessionCompleteScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (c, s) =>
                const Scaffold(body: Center(child: Text('stub:home'))),
          ),
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
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    testWidgets('1st completion is sampled; 😊 writes rating 3',
        (tester) async {
      await completeFirstSession(tester);

      expect(find.text('How was this session?'), findsOneWidget);
      await tester.ensureVisible(find.text('😊'));
      await tester.pump();
      await tester.tap(find.text('😊'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // Row disappears after answering; entry persisted with context.
      expect(find.text('How was this session?'), findsNothing);
      final entries =
          await container.read(feedbackRepositoryProvider).all();
      expect(entries.single.rating, 3);
      expect(entries.single.type, 'post_session');
      expect(entries.single.contextJson, contains('"plannedMin":30'));
    });

    testWidgets('😔 asks the follow-up and stores the reason',
        (tester) async {
      await completeFirstSession(tester);

      await tester.ensureVisible(find.text('😔'));
      await tester.pump();
      await tester.tap(find.text('😔'));
      await tester.pump();
      await tester.ensureVisible(find.text('Blocking failed'));
      await tester.pump();
      await tester.tap(find.text('Blocking failed'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      final entries =
          await container.read(feedbackRepositoryProvider).all();
      expect(entries.single.rating, 1);
      expect(entries.single.feedbackText, 'blockingFailed');
    });
  });
}
