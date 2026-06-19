import 'package:flutter/material.dart';

import 'eos_breakpoints.dart';
import 'eos_radius.dart';
import 'eos_shadows.dart';
import 'eos_spacing.dart';

/// Theme extension — access design tokens anywhere via [BuildContext.eos].
@immutable
class EosTokens extends ThemeExtension<EosTokens> {
  const EosTokens({
    required this.spacing,
    required this.radius,
    required this.shadowSoft,
    required this.shadowElevated,
    required this.breakpoints,
  });

  final EosSpacingRef spacing;
  final EosRadiusRef radius;
  final List<BoxShadow> shadowSoft;
  final List<BoxShadow> shadowElevated;
  final EosBreakpointsRef breakpoints;

  factory EosTokens.fromScheme(ColorScheme scheme) => EosTokens(
        spacing: const EosSpacingRef(),
        radius: const EosRadiusRef(),
        shadowSoft: EosShadows.soft(scheme.shadow),
        shadowElevated: EosShadows.elevated(scheme.shadow),
        breakpoints: const EosBreakpointsRef(),
      );

  @override
  EosTokens copyWith({
    EosSpacingRef? spacing,
    EosRadiusRef? radius,
    List<BoxShadow>? shadowSoft,
    List<BoxShadow>? shadowElevated,
    EosBreakpointsRef? breakpoints,
  }) {
    return EosTokens(
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowElevated: shadowElevated ?? this.shadowElevated,
      breakpoints: breakpoints ?? this.breakpoints,
    );
  }

  @override
  EosTokens lerp(ThemeExtension<EosTokens>? other, double t) {
    if (other is! EosTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Namespaced spacing access on [EosTokens].
class EosSpacingRef {
  const EosSpacingRef();
  double get xxs => EosSpacing.xxs;
  double get xs => EosSpacing.xs;
  double get sm => EosSpacing.sm;
  double get md => EosSpacing.md;
  double get lg => EosSpacing.lg;
  double get xl => EosSpacing.xl;
  double get xxl => EosSpacing.xxl;
  EdgeInsets get page => EosSpacing.pagePadding;
  EdgeInsets get card => EosSpacing.cardPadding;
}

class EosRadiusRef {
  const EosRadiusRef();
  BorderRadius get card => EosRadius.card;
  BorderRadius get chip => EosRadius.chip;
  BorderRadius get input => EosRadius.input;
}

class EosBreakpointsRef {
  const EosBreakpointsRef();
  double get mobile => EosBreakpoints.mobile;
  double get tablet => EosBreakpoints.tablet;
  double get desktop => EosBreakpoints.desktop;
}
