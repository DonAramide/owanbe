import 'package:flutter/material.dart';
import 'eos_design_tokens.dart';

abstract final class EosRadius {
  static const double xs = EosDesignTokens.radiusCompact;
  static const double sm = EosDesignTokens.radiusCompact;
  static const double md = EosDesignTokens.radiusMedium;
  static const double lg = EosDesignTokens.radiusLarge;
  static const double xl = EosDesignTokens.radiusLarge;
  static const double pill = 999.0;

  static final BorderRadius card = BorderRadius.circular(md);
  static final BorderRadius chip = BorderRadius.circular(pill);
  static final BorderRadius input = BorderRadius.circular(sm);
  static final BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xl));
}
