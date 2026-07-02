/// Spacing + radii scales per design/DESIGN_SYSTEM.md §3–4.
abstract final class FokusSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Default horizontal screen inset.
  static const double screenPadding = 20;

  /// Between major blocks.
  static const double sectionGap = 32;

  static const double cardPadding = 20;

  /// Enforced on every interactive element.
  static const double minTouchTarget = 48;
}

abstract final class FokusRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double full = 999;
}
