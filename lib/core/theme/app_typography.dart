import 'package:flutter/material.dart';

/// TextTheme per design/DESIGN_SYSTEM.md §2.
/// Family Plus Jakarta Sans is NOT bundled yet — font-bundling decision is
/// open with Prashant (B-01 review); sizes/weights/leading ship now so screens
/// build against final metrics.
abstract final class AppTypography {
  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
        fontSize: 57, fontWeight: FontWeight.w700, height: 1.12, letterSpacing: -0.5),
    displayMedium: TextStyle(
        fontSize: 45, fontWeight: FontWeight.w700, height: 1.16, letterSpacing: 0),
    displaySmall: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w600, height: 1.22, letterSpacing: 0),
    headlineLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: 0),
    headlineMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w600, height: 1.29, letterSpacing: 0),
    headlineSmall: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w600, height: 1.33, letterSpacing: 0),
    titleLarge: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w600, height: 1.27, letterSpacing: 0),
    titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, letterSpacing: 0.15),
    titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, height: 1.43, letterSpacing: 0.1),
    bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, letterSpacing: 0.15),
    bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, height: 1.43, letterSpacing: 0.1),
    bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, height: 1.33, letterSpacing: 0.2),
    labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, height: 1.43, letterSpacing: 0.1),
    labelMedium: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, height: 1.33, letterSpacing: 0.2),
    labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, height: 1.45, letterSpacing: 0.3),
  );

  /// Custom style: active-session countdown (tabular figures, tight tracking).
  static const TextStyle countdown = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
