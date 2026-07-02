import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../application/achievement_engine.dart';

/// Badge art from `assets/achievements/` (design/assets badge_*.svg set).
/// Night Owl and Exam Hero have no art yet — themed Icon fallback
/// (ux-designer debt noted on F-15).
const Map<AchievementCode, String> _badgeAssets = {
  AchievementCode.firstSession: 'badge_first_session',
  AchievementCode.earlyBird: 'badge_early_bird',
  AchievementCode.distractionDestroyer: 'badge_distraction_destroyer',
  AchievementCode.recoveryChampion: 'badge_recovery_champion',
  AchievementCode.ironWill: 'badge_iron_will',
  AchievementCode.twoWeekWarrior: 'badge_two_week_warrior',
};

const Map<AchievementCode, IconData> _fallbackIcons = {
  AchievementCode.nightOwl: Icons.dark_mode_outlined,
  AchievementCode.examHero: Icons.school_outlined,
};

/// Localized display name + one-liner for a code (all copy in ARB).
extension AchievementCopy on AchievementCode {
  String nameOf(AppLocalizations l10n) => switch (this) {
        AchievementCode.firstSession => l10n.achFirstSessionName,
        AchievementCode.earlyBird => l10n.achEarlyBirdName,
        AchievementCode.nightOwl => l10n.achNightOwlName,
        AchievementCode.distractionDestroyer =>
          l10n.achDistractionDestroyerName,
        AchievementCode.recoveryChampion => l10n.achRecoveryChampionName,
        AchievementCode.ironWill => l10n.achIronWillName,
        AchievementCode.examHero => l10n.achExamHeroName,
        AchievementCode.twoWeekWarrior => l10n.achTwoWeekWarriorName,
      };

  String descriptionOf(AppLocalizations l10n) => switch (this) {
        AchievementCode.firstSession => l10n.achFirstSessionDesc,
        AchievementCode.earlyBird => l10n.achEarlyBirdDesc,
        AchievementCode.nightOwl => l10n.achNightOwlDesc,
        AchievementCode.distractionDestroyer =>
          l10n.achDistractionDestroyerDesc,
        AchievementCode.recoveryChampion => l10n.achRecoveryChampionDesc,
        AchievementCode.ironWill => l10n.achIronWillDesc,
        AchievementCode.examHero => l10n.achExamHeroDesc,
        AchievementCode.twoWeekWarrior => l10n.achTwoWeekWarriorDesc,
      };
}

/// One badge's art: the SVG from `assets/achievements/` when it exists, else
/// a themed icon in a circular frame. Locked badges render desaturated and
/// dimmed. Decorative — the surrounding tile carries semantics.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.code,
    this.unlocked = true,
    this.size = 56,
  });

  final AchievementCode code;
  final bool unlocked;
  final double size;

  /// Saturation-0 matrix — greys out locked badge art.
  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = _badgeAssets[code];

    Widget art;
    if (asset != null) {
      art = SvgPicture.asset(
        'assets/achievements/$asset.svg',
        width: size,
        height: size,
      );
    } else {
      // TODO(F-15): missing badge art (Night Owl, Exam Hero) — ux-designer.
      art = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        alignment: Alignment.center,
        child: Icon(
          _fallbackIcons[code],
          size: size * 0.5,
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (!unlocked) {
      art = Opacity(
        opacity: 0.4,
        child: ColorFiltered(colorFilter: _greyscale, child: art),
      );
    }
    return ExcludeSemantics(child: art);
  }
}
