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
import 'package:fokus/features/onboarding/presentation/onboarding_screen.dart';
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
      ..permissionMap = {
        PermissionKind.accessibility: false,
        PermissionKind.usageStats: false,
        PermissionKind.notifications: true,
        PermissionKind.batteryExemption: false,
      }
      ..installedApps = const [
        InstalledApp(packageName: 'com.instagram.android', appName: 'Instagram'),
        InstalledApp(packageName: 'com.google.android.apps.maps', appName: 'Maps'),
        InstalledApp(packageName: 'com.spotify.music', appName: 'Spotify'),
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

  Future<void> pumpOnboarding(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (c, s) => const OnboardingScreen(),
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
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> throughValuePages(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Get started'));
    await settle(tester);
  }

  testWidgets('value pages carry the blueprint §6.7 copy, then disclosure',
      (tester) async {
    await pumpOnboarding(tester);

    expect(
      find.text('Take back control of your screen time'),
      findsOneWidget,
    );
    await throughValuePages(tester);

    expect(find.text('How FOKUS blocks apps'), findsOneWidget);
    // Play policy: NOTHING may have opened a settings screen yet.
    expect(fake.requestedPermissions, isEmpty);
  });

  testWidgets('skip never bypasses the disclosure', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(find.text('How FOKUS blocks apps'), findsOneWidget);
  });

  testWidgets('disclosure "Not now" → limited mode, zero settings redirects',
      (tester) async {
    await pumpOnboarding(tester);
    await throughValuePages(tester);

    await tester.tap(find.text('Not now'));
    await settle(tester);

    expect(find.text('stub:home'), findsOneWidget);
    expect(prefs.getBool(PrefKeys.onboardingSeen), isTrue);
    expect(fake.requestedPermissions, isEmpty);
  });

  testWidgets(
      'permission checklist: badges reflect status; Set up fires only after '
      'consent', (tester) async {
    await pumpOnboarding(tester);
    await throughValuePages(tester);
    await tester.tap(find.text('I understand — continue'));
    await settle(tester);

    expect(find.text('Set up FOKUS'), findsOneWidget);
    expect(find.text('1 of 4 set up'), findsOneWidget); // notifications only
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Action needed'), findsNWidgets(3));

    await tester.tap(find.text('Set up').first);
    await settle(tester);
    expect(fake.requestedPermissions, [PermissionKind.accessibility]);
  });

  testWidgets('full flow: pickers persist blocked + allowlist (D-011)',
      (tester) async {
    await pumpOnboarding(tester);
    await throughValuePages(tester);
    await tester.tap(find.text('I understand — continue'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // Blocked picker: Instagram surfaces under "Commonly blocked".
    expect(find.text('Which apps pull you away?'), findsOneWidget);
    expect(find.text('Commonly blocked'), findsOneWidget);
    await tester.tap(find.text('Instagram'));
    await settle(tester);
    await tester.tap(find.textContaining('Done'));
    await settle(tester);

    // Allowlist picker: the blocked pick is excluded (never both — D-011).
    expect(find.text('Any apps you always need?'), findsOneWidget);
    expect(find.text('Instagram'), findsNothing);
    await tester.tap(find.text('Maps'));
    await settle(tester);
    await tester.tap(find.textContaining('Done'));
    await settle(tester);

    expect(find.text('stub:home'), findsOneWidget);
    expect(prefs.getBool(PrefKeys.onboardingSeen), isTrue);

    final lists = container.read(appListsRepositoryProvider);
    final blocked = await lists.getBlockedApps();
    expect(blocked.single.packageName, 'com.instagram.android');
    final allowed = await lists.getAllowlistedApps();
    expect(allowed.single.packageName, 'com.google.android.apps.maps');
    // Native cache synced with the picked blocked set.
    expect(fake.blockedAppSets.single, ['com.instagram.android']);
  });
}

class _Stub extends StatelessWidget {
  const _Stub(this.name);
  final String name;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('stub:$name')));
}
