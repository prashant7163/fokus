import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/blocking_adapter.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/prefs.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/theme/app_theme.dart';
import 'package:fokus/features/settings/presentation/settings_screen.dart';
import 'package:fokus/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/test_db.dart';
import '../../core/session/fake_blocking_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FokusDatabase db;
  late FakeBlockingAdapter fake;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = testDb();
    fake = FakeBlockingAdapter()
      ..installedApps = const [
        InstalledApp(packageName: 'com.instagram.android', appName: 'Instagram'),
        InstalledApp(packageName: 'com.google.android.apps.maps', appName: 'Maps'),
      ];
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      blockingAdapterProvider.overrideWithValue(fake),
      sharedPreferencesProvider.overrideWithValue(prefs),
      tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await fake.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
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
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('healthy permissions show the all-good card', (tester) async {
    await pump(tester);
    expect(
      find.text("Everything's active — sessions are protected."),
      findsOneWidget,
    );
    expect(find.text('Fix'), findsNothing);
  });

  testWidgets('degraded permissions show Fix that deep-links settings',
      (tester) async {
    fake.permissionMap = {
      ...fake.permissionMap,
      PermissionKind.accessibility: false,
    };
    await pump(tester);

    expect(find.text('Some permissions need attention.'), findsOneWidget);
    await tester.tap(find.text('Fix'));
    expect(fake.requestedPermissions, [PermissionKind.accessibility]);
  });

  testWidgets('theme choice persists (D-009 light default)', (tester) async {
    await pump(tester);
    expect(container.read(themeModeProvider), ThemeMode.light);

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(prefs.getString(PrefKeys.themeMode), 'dark');
  });

  testWidgets('smart suggestions opt-in is off by default and persists',
      (tester) async {
    await pump(tester);
    expect(container.read(smartSuggestionsProvider), isFalse);

    await tester.tap(find.text('Smart Suggestions (beta)'));
    await tester.pump();

    expect(container.read(smartSuggestionsProvider), isTrue);
    expect(prefs.getBool(PrefKeys.smartSuggestions), isTrue);
  });

  testWidgets('allowlist is editable from settings (D-011)', (tester) async {
    await pump(tester);
    // The row sits below the 600px test fold — scroll it into view.
    await tester.scrollUntilVisible(
      find.text('Always-available apps'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('Always-available apps'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text('Maps'));
    await tester.pump();
    await tester.tap(find.textContaining('Done'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final allowed =
        await container.read(appListsRepositoryProvider).getAllowlistedApps();
    expect(allowed.single.packageName, 'com.google.android.apps.maps');
  });
}
