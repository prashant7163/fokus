import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/app.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/prefs.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/features/home/presentation/home_screen.dart';
import 'package:fokus/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/data/test_db.dart';
import 'core/session/fake_blocking_adapter.dart';

void main() {
  late FokusDatabase db;
  late FakeBlockingAdapter fake;

  setUp(() {
    db = testDb();
    fake = FakeBlockingAdapter();
  });

  tearDown(() async {
    await fake.dispose();
    await db.close();
  });

  Future<Widget> app({bool onboardingSeen = true}) async {
    SharedPreferences.setMockInitialValues(
      {if (onboardingSeen) PrefKeys.onboardingSeen: true},
    );
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        blockingAdapterProvider.overrideWithValue(fake),
        tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
      ],
      child: const FokusApp(),
    );
  }

  testWidgets('app boots to home with EN strings', (tester) async {
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('FOKUS'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
  });

  testWidgets('first launch boots to onboarding (F-10)', (tester) async {
    await tester.pumpWidget(await app(onboardingSeen: false));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
      find.text('Take back control of your screen time'),
      findsOneWidget,
    );
  });

  testWidgets('app renders DE locale', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    expect(find.text('Neue Session'), findsOneWidget);
  });
}
