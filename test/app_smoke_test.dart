import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/app.dart';
import 'package:fokus/core/prefs.dart';
import 'package:fokus/features/home/presentation/home_screen.dart';
import 'package:fokus/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<Widget> app({bool onboardingSeen = true}) async {
    SharedPreferences.setMockInitialValues(
      {if (onboardingSeen) PrefKeys.onboardingSeen: true},
    );
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FokusApp(),
    );
  }

  testWidgets('app boots to home with EN strings', (tester) async {
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
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

    expect(find.text('Start'), findsWidgets);
  });
}
