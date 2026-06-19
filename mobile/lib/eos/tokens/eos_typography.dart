import 'package:flutter/material.dart';

import 'eos_colors.dart';

/// EOS typography scale — swap [fontFamily] when custom fonts are bundled.
abstract final class EosTypography {
  static const String fontFamily = 'Roboto';
  static const List<String> fontFamilyFallback = ['Segoe UI', 'Helvetica Neue', 'Arial'];

  static TextTheme textTheme(ColorScheme scheme) {
    TextStyle base({
      required double size,
      required FontWeight weight,
      double height = 1.35,
      double letterSpacing = 0,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? scheme.onSurface,
      );
    }

    return TextTheme(
      displayLarge: base(size: 48, weight: FontWeight.w700, height: 1.15, letterSpacing: -0.5),
      displayMedium: base(size: 40, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.4),
      displaySmall: base(size: 32, weight: FontWeight.w700, height: 1.25, letterSpacing: -0.3),
      headlineLarge: base(size: 28, weight: FontWeight.w700, height: 1.25),
      headlineMedium: base(size: 24, weight: FontWeight.w600, height: 1.3),
      headlineSmall: base(size: 20, weight: FontWeight.w600, height: 1.35),
      titleLarge: base(size: 18, weight: FontWeight.w600),
      titleMedium: base(size: 16, weight: FontWeight.w600),
      titleSmall: base(size: 14, weight: FontWeight.w600),
      bodyLarge: base(size: 16, weight: FontWeight.w400),
      bodyMedium: base(size: 14, weight: FontWeight.w400, color: scheme.onSurfaceVariant),
      bodySmall: base(size: 12, weight: FontWeight.w400, color: scheme.onSurfaceVariant),
      labelLarge: base(size: 14, weight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium: base(size: 12, weight: FontWeight.w600, letterSpacing: 0.3),
      labelSmall: base(
        size: 11,
        weight: FontWeight.w600,
        letterSpacing: 0.4,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  /// KPI / metric numerals — tabular, high contrast.
  static TextStyle metric(ColorScheme scheme, {double size = 28}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: scheme.onSurface,
      );

  static TextStyle overline(ColorScheme scheme) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: EosColors.slate500,
      );
}
