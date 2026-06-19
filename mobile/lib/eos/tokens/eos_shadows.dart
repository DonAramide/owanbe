import 'package:flutter/material.dart';

abstract final class EosShadows {
  static List<BoxShadow> soft(Color base) => [
        BoxShadow(
          color: base.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: base.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> elevated(Color base) => [
        BoxShadow(
          color: base.withValues(alpha: 0.10),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ];
}
