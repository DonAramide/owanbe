import 'package:flutter/material.dart';
import 'eos_design_tokens.dart';

/// EOS spacing scale — generous whitespace for premium SaaS / fintech feel.
abstract final class EosSpacing {
  static const double xxs = EosDesignTokens.spaceXxs;
  static const double xs = EosDesignTokens.spaceXs;
  static const double sm = EosDesignTokens.spaceSm;
  static const double md = EosDesignTokens.spaceMd;
  static const double lg = EosDesignTokens.spaceLg;
  static const double xl = EosDesignTokens.spaceXl;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets sectionGap = EdgeInsets.only(bottom: xl);
}
