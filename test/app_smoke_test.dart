import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/app.dart';
import 'package:fokus/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('app boots to home with EN strings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FokusApp()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('app renders DE locale', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const ProviderScope(child: FokusApp()));
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsWidgets);
  });
}
