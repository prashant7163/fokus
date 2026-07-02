import 'package:flutter/animation.dart';

/// Motion tokens per design/DESIGN_SYSTEM.md §6.
abstract final class FokusMotion {
  static const Duration instant = Duration.zero;
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration calm = Duration(milliseconds: 400);
  static const Duration breath = Duration(milliseconds: 4000);
  static const Duration celebrate = Duration(milliseconds: 700);

  static const Curve curveQuick = Curves.easeOutCubic;
  static const Curve curveBase = Curves.easeInOutCubic;
  static const Curve curveCalm = Curves.easeOutCubic;
  static const Curve curveBreath = Curves.easeInOutSine;
  static const Curve curveCelebrate = Curves.easeOutBack; // clamp overshoot ≤1.05
}
