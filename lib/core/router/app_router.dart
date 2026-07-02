import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/recovery/presentation/recovery_screen.dart';
import '../../features/session/presentation/exit_screen.dart';
import '../../features/session/presentation/session_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';

/// Route names — single source for navigation targets.
abstract final class AppRoutes {
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String session = '/session';
  static const String recovery = '/recovery';
  static const String exit = '/exit';
  static const String stats = '/stats';
  static const String settings = '/settings';
}

/// App-wide router. Placeholder screens; each feature task (F-07…F-12)
/// replaces its stub and may add sub-routes within its own feature folder.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.session,
        builder: (context, state) => const SessionScreen(),
      ),
      // Deep-link targets: InterceptActivity lands here via fokus://recovery
      // (optionally `?module=breathe` — the proactive hint pre-selects
      // Breathe) and fokus://exit. Context is received here and forwarded;
      // F-07/F-08 own the real screens.
      GoRoute(
        path: AppRoutes.recovery,
        builder: (context, state) => RecoveryScreen(
          preselectedModule: state.uri.queryParameters['module'],
        ),
      ),
      GoRoute(
        path: AppRoutes.exit,
        builder: (context, state) => const ExitScreen(),
      ),
      GoRoute(
        path: AppRoutes.stats,
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
