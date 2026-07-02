import 'package:flutter/material.dart';

/// Color schemes per design/DESIGN_SYSTEM.md §1 (v2 palette, D-009).
/// Note: the spec's `surfaceVariant` role is deprecated in ColorScheme;
/// its value lives on as [FokusColors.ringTrack] and `outlineVariant` usage.
const ColorScheme lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFC24A16),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFE4D2),
  onPrimaryContainer: Color(0xFF4A1B04),
  secondary: Color(0xFF5A6152),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDDE7D0),
  onSecondaryContainer: Color(0xFF26301E),
  tertiary: Color(0xFF785A0B),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFBEBC8),
  onTertiaryContainer: Color(0xFF4A3200),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  surface: Color(0xFFFBF9F6),
  onSurface: Color(0xFF22201D),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFAF7F2),
  surfaceContainer: Color(0xFFF5F2EC),
  surfaceContainerHigh: Color(0xFFEFEBE3),
  surfaceContainerHighest: Color(0xFFE9E4DA),
  onSurfaceVariant: Color(0xFF55524C),
  outline: Color(0xFF84807A),
  outlineVariant: Color(0xFFD6CFC3),
  surfaceTint: Color(0xFFC24A16),
  inverseSurface: Color(0xFF332F2A),
  onInverseSurface: Color(0xFFF3EFE9),
  inversePrimary: Color(0xFFFFB68C),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

const ColorScheme darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFFB68C),
  onPrimary: Color(0xFF3A1600),
  primaryContainer: Color(0xFF7A3410),
  onPrimaryContainer: Color(0xFFFFDBC7),
  secondary: Color(0xFFBCCBAC),
  onSecondary: Color(0xFF28331C),
  secondaryContainer: Color(0xFF3E4833),
  onSecondaryContainer: Color(0xFFDDE7D0),
  tertiary: Color(0xFFF2C24E),
  onTertiary: Color(0xFF3A2B00),
  tertiaryContainer: Color(0xFF574200),
  onTertiaryContainer: Color(0xFFFBEBC8),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF20201E),
  onSurface: Color(0xFFECE7E0),
  surfaceContainerLowest: Color(0xFF161513),
  surfaceContainerLow: Color(0xFF201F1D),
  surfaceContainer: Color(0xFF242320),
  surfaceContainerHigh: Color(0xFF2E2C28),
  surfaceContainerHighest: Color(0xFF383530),
  onSurfaceVariant: Color(0xFFCFC8BF),
  outline: Color(0xFF9A968E),
  outlineVariant: Color(0xFF3A382F),
  surfaceTint: Color(0xFFFFB68C),
  inverseSurface: Color(0xFFECE7E0),
  onInverseSurface: Color(0xFF332F2A),
  inversePrimary: Color(0xFFC24A16),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

/// Brand extras not expressible as ColorScheme roles (DESIGN_SYSTEM.md §1).
@immutable
class FokusColors extends ThemeExtension<FokusColors> {
  const FokusColors({
    required this.focusGradient,
    required this.calmWash,
    required this.streakSignal,
    required this.ringTrack,
    required this.scrimIntercept,
  });

  /// Ember gradient — hero CTA / progress arc.
  final Gradient focusGradient;

  /// Sage wash — recovery surfaces.
  final Gradient calmWash;

  /// Warm-gold streak signal.
  final Color streakSignal;

  /// Unfilled part of the progress ring (spec's surfaceVariant).
  final Color ringTrack;

  /// Full-screen scrim under intercept/recovery overlays.
  final Color scrimIntercept;

  static const FokusColors light = FokusColors(
    focusGradient: LinearGradient(
      colors: [Color(0xFFFF7A30), Color(0xFFE8611F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight, // ≈135°
    ),
    calmWash: LinearGradient(
      colors: [Color(0xFF8FA07E), Color(0xFFB7C3A5)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter, // ≈160°
    ),
    streakSignal: Color(0xFF785A0B),
    ringTrack: Color(0xFFEAE4DA),
    scrimIntercept: Color(0x8C000000), // scrim @ 0.55
  );

  static const FokusColors dark = FokusColors(
    focusGradient: LinearGradient(
      colors: [Color(0xFFFF7A30), Color(0xFFE8611F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    calmWash: LinearGradient(
      colors: [Color(0xFF8FA07E), Color(0xFFB7C3A5)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    streakSignal: Color(0xFFF2C24E),
    ringTrack: Color(0xFF3A382F),
    scrimIntercept: Color(0x8C000000),
  );

  @override
  FokusColors copyWith({
    Gradient? focusGradient,
    Gradient? calmWash,
    Color? streakSignal,
    Color? ringTrack,
    Color? scrimIntercept,
  }) {
    return FokusColors(
      focusGradient: focusGradient ?? this.focusGradient,
      calmWash: calmWash ?? this.calmWash,
      streakSignal: streakSignal ?? this.streakSignal,
      ringTrack: ringTrack ?? this.ringTrack,
      scrimIntercept: scrimIntercept ?? this.scrimIntercept,
    );
  }

  @override
  FokusColors lerp(FokusColors? other, double t) {
    if (other == null) return this;
    return FokusColors(
      focusGradient: Gradient.lerp(focusGradient, other.focusGradient, t) ??
          focusGradient,
      calmWash: Gradient.lerp(calmWash, other.calmWash, t) ?? calmWash,
      streakSignal:
          Color.lerp(streakSignal, other.streakSignal, t) ?? streakSignal,
      ringTrack: Color.lerp(ringTrack, other.ringTrack, t) ?? ringTrack,
      scrimIntercept:
          Color.lerp(scrimIntercept, other.scrimIntercept, t) ?? scrimIntercept,
    );
  }
}
