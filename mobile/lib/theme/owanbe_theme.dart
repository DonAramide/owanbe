import 'package:flutter/material.dart';

/// Brand-forward seed; tune when design tokens land.
final ThemeData owanbeTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4B2C6F),
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(centerTitle: true),
);
