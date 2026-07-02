import 'package:flutter/material.dart';

class EosDesignTokens {
  // Brand Base Colors
  static const Color primaryBase = Color(0xFF5B4CF0);
  static const Color successBase = Color(0xFF16A34A);
  static const Color warningBase = Color(0xFFF59E0B);
  static const Color dangerBase = Color(0xFFDC2626);

  // Spacing Scale
  static const double spaceXxs = 4.0;
  static const double spaceXs = 8.0;
  static const double spaceSm = 12.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // BorderRadius scale
  static const double radiusCompact = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Motion timings
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Curve curveDefault = Curves.easeInOut;

  // Opacity indicators
  static const double opacityMuted = 0.6;
  static const double opacityDisabled = 0.38;
}
