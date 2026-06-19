import 'package:flutter/material.dart';

class EosNavDestination {
  const EosNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? badge;
}
