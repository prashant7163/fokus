import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-level key-value flags (D-018): onboarding seen, F-12 settings
/// toggles. Never behavioral data — that lives in the drift DB.
abstract final class PrefKeys {
  static const onboardingSeen = 'onboarding_seen';
  static const themeMode = 'theme_mode';
  static const smartSuggestions = 'smart_suggestions_enabled';
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

/// Theme selection (F-12). Default LIGHT per D-009 (light theme default,
/// orange single accent); System/Dark are user choices.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final raw =
        ref.watch(sharedPreferencesProvider).getString(PrefKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ThemeMode.light,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.themeMode, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Smart Suggestions master opt-in (spec §3.10) — OFF by default, consumed
/// by F-17. Stored here so the F-12 toggle and F-17 engine agree.
class SmartSuggestionsController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(PrefKeys.smartSuggestions) ??
      false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.smartSuggestions, enabled);
  }
}

final smartSuggestionsProvider =
    NotifierProvider<SmartSuggestionsController, bool>(
  SmartSuggestionsController.new,
);
