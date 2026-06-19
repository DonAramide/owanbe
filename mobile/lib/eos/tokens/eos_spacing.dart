import 'package:flutter/material.dart';

/// EOS spacing scale — generous whitespace for premium SaaS / fintech feel.
abstract final class EosSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets sectionGap = EdgeInsets.only(bottom: xl);
}
