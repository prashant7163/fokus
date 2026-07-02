import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles ThemeData per design/DESIGN_SYSTEM.md (§1–§7).
abstract final class AppTheme {
  static ThemeData light() => _build(lightScheme, FokusColors.light);

  static ThemeData dark() => _build(darkScheme, FokusColors.dark);

  static ThemeData _build(ColorScheme scheme, FokusColors extras) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [extras],
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FokusRadius.sm),
    );
    const buttonPadding =
        EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    const buttonMinSize = Size(FokusSpacing.minTouchTarget, FokusSpacing.minTouchTarget);

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle:
            AppTypography.textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: scheme.brightness == Brightness.light ? 1 : 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FokusRadius.md),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FokusRadius.sm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FokusRadius.sm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FokusRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(FokusRadius.lg)),
        ),
        dragHandleColor: scheme.outlineVariant,
        dragHandleSize: const Size(32, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FokusRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: AppTypography.textTheme.bodyMedium
            ?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FokusRadius.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        // Explicit color: a labelStyle without one bypasses the chip's own
        // color resolution and inherits whatever DefaultTextStyle is above —
        // unselected chips rendered near-white (found in the F-11/F-12
        // emulator pass).
        labelStyle: AppTypography.textTheme.labelLarge
            ?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
