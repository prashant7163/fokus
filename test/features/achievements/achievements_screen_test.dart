import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/achievements/presentation/achievements_screen.dart';
import 'package:fokus/l10n/generated/app_localizations.dart';

import '../../core/data/test_db.dart';

/// F-15 badge screen: all 8 achievements listed with locked/unlocked states
/// and unlock dates; art-less codes fall back to themed icons.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lists all 8 badges with locked/unlocked states',
      (tester) async {
    final db = testDb();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // One unlocked, seven locked.
    await container
        .read(achievementRepositoryProvider)
        .insertIfAbsent('firstSession', DateTime(2026, 7, 1, 9, 30));

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
          home: const AchievementsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // All 8 names render (screen title also reads "Achievements").
    expect(find.text('Achievements'), findsOneWidget);
    for (final name in [
      'First Session',
      'Early Bird',
      'Night Owl',
      'Distraction Destroyer',
      'Recovery Champion',
      'Iron Will',
      'Exam Hero',
      'Two Week Warrior',
    ]) {
      await tester.scrollUntilVisible(find.text(name), 120,
          scrollable: find.byType(Scrollable));
      expect(find.text(name), findsOneWidget);
    }

    // Unlocked state: date line on the earned badge, "Locked" on the rest.
    await tester.scrollUntilVisible(find.text('First Session'), -120,
        scrollable: find.byType(Scrollable));
    expect(find.text('Unlocked Jul 1, 2026'), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);

    // Night Owl and Exam Hero have no badge art yet — themed icon fallback.
    await tester.scrollUntilVisible(
        find.byIcon(Icons.dark_mode_outlined), 120,
        scrollable: find.byType(Scrollable));
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    await tester.scrollUntilVisible(find.byIcon(Icons.school_outlined), 120,
        scrollable: find.byType(Scrollable));
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
  });
}
