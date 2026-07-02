import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-level key-value flags (D-018): onboarding seen, later F-12 settings
/// toggles. Never behavioral data — that lives in the drift DB.
abstract final class PrefKeys {
  static const onboardingSeen = 'onboarding_seen';
}

/// Loaded in main() before runApp and provided via override — synchronous
/// reads everywhere after that.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden at bootstrap'),
);

final onboardingSeenProvider = Provider<bool>(
  (ref) =>
      ref.watch(sharedPreferencesProvider).getBool(PrefKeys.onboardingSeen) ??
      false,
);
