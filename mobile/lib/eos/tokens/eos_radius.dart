import 'package:flutter/material.dart';

abstract final class EosRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static final BorderRadius card = BorderRadius.circular(md);
  static final BorderRadius chip = BorderRadius.circular(pill);
  static final BorderRadius input = BorderRadius.circular(sm);
  static final BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xl));
}
