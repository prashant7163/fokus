import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/constants.dart';
import 'package:fokus/core/theme/app_colors.dart';
import 'package:fokus/core/theme/app_theme.dart';

void main() {
  group('theme (DESIGN_SYSTEM.md §1)', () {
    test('light scheme matches v2 palette anchors', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFFC24A16));
      expect(theme.colorScheme.surface, const Color(0xFFFBF9F6));
      expect(theme.extension<FokusColors>(), isNotNull);
    });

    test('dark scheme matches v2 palette anchors', () {
      final theme = AppTheme.dark();
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, const Color(0xFFFFB68C));
      expect(theme.colorScheme.surface, const Color(0xFF20201E));
      expect(theme.extension<FokusColors>(), isNotNull);
    });
  });

  group('business constants (CONTRACTS.md §4)', () {
    test('durations, streak rule, token economy', () {
      expect(FokusConstants.sessionDurationsMin, [15, 30, 60, 120]);
      expect(FokusConstants.streakQualifyingSessionMin, 10);
      expect(FokusConstants.lockBreakMilestones,
          {7: 1, 14: 2, 30: 3, 60: 5, 100: 10});
      expect(FokusConstants.lockBreakWeeklyRedeemCap, 3);
      expect(FokusConstants.feedbackSamplingOneIn, 3);
      expect(FokusConstants.taskAnchorMaxChars, 80);
    });
  });
}
