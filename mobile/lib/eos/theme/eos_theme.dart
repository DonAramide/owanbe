import 'package:flutter/material.dart';

import '../tokens/eos_colors.dart';
import '../tokens/eos_radius.dart';
import '../tokens/eos_spacing.dart';
import '../tokens/eos_tokens.dart';
import '../tokens/eos_typography.dart';

/// Builds Material [ThemeData] wired to EOS tokens.
abstract final class EosTheme {
  static ThemeData light() => _build(EosColors.lightScheme());

  static ThemeData dark() => _build(EosColors.darkScheme(), brightness: Brightness.dark);

  static ThemeData _build(ColorScheme scheme, {Brightness brightness = Brightness.light}) {
    final textTheme = EosTypography.textTheme(scheme);
    final tokens = EosTokens.fromScheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light ? EosColors.canvas : scheme.surface,
      textTheme: textTheme,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: EosRadius.card,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: EosSpacing.md, vertical: EosSpacing.sm),
        border: OutlineInputBorder(borderRadius: EosRadius.input),
        enabledBorder: OutlineInputBorder(
          borderRadius: EosRadius.input,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: EosRadius.input,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      visualDensity: VisualDensity.standard,
    );
  }
}
