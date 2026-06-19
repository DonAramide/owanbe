import 'package:flutter/material.dart';

/// EOS brand and semantic palette — event premium + fintech clarity.
abstract final class EosColors {
  // Brand
  static const Color plum = Color(0xFF4B2C6F);
  static const Color plumDark = Color(0xFF2E1A45);
  static const Color plumLight = Color(0xFF7B4FA3);
  static const Color champagne = Color(0xFFD4A853);
  static const Color champagneLight = Color(0xFFF3E2B8);

  // Neutrals (slate family)
  static const Color ink = Color(0xFF0F172A);
  static const Color slate900 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color canvas = Color(0xFFF8F7FC);
  static const Color surface = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF0D9488);
  static const Color successSoft = Color(0xFFCCFBF1);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFEDD5);
  static const Color critical = Color(0xFFDC2626);
  static const Color criticalSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color live = Color(0xFF16A34A);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: plum,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDE4F5),
      onPrimaryContainer: plumDark,
      secondary: champagne,
      onSecondary: plumDark,
      secondaryContainer: champagneLight,
      onSecondaryContainer: plumDark,
      tertiary: info,
      onTertiary: Colors.white,
      error: critical,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: slate700,
      outline: slate300,
      outlineVariant: slate100,
      shadow: Color(0x1A0F172A),
      surfaceContainerHighest: slate100,
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: plumLight,
      onPrimary: Colors.white,
      primaryContainer: plumDark,
      onPrimaryContainer: champagneLight,
      secondary: champagne,
      onSecondary: plumDark,
      secondaryContainer: Color(0xFF3D2E14),
      onSecondaryContainer: champagneLight,
      tertiary: Color(0xFF60A5FA),
      onTertiary: ink,
      error: Color(0xFFF87171),
      onError: ink,
      surface: Color(0xFF12101A),
      onSurface: Color(0xFFF8FAFC),
      onSurfaceVariant: slate300,
      outline: slate700,
      outlineVariant: slate900,
      shadow: Colors.black,
      surfaceContainerHighest: slate900,
    );
  }
}
