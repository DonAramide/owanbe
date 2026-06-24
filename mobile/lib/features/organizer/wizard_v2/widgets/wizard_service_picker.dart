import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

/// Checkbox grid for required vendor services (not specific vendors).
class WizardServicePicker extends StatelessWidget {
  const WizardServicePicker({
    super.key,
    required this.services,
    required this.selected,
    required this.onToggle,
  });

  final List<String> services;
  final Set<String> selected;
  final void Function(String service, bool on) onToggle;

  static const _icons = <String, IconData>{
    'Venue': Icons.apartment_outlined,
    'Catering': Icons.restaurant_outlined,
    'Decorator': Icons.celebration_outlined,
    'Photographer': Icons.photo_camera_outlined,
    'DJ': Icons.music_note_outlined,
    'MC': Icons.mic_outlined,
    'Security': Icons.security_outlined,
    'Cake': Icons.cake_outlined,
    'Drinks': Icons.local_bar_outlined,
    'Ushers': Icons.people_outline,
    'Live Band': Icons.piano_outlined,
    'Production': Icons.theaters_outlined,
    'AV Production': Icons.surround_sound_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        for (final service in services)
          FilterChip(
            avatar: Icon(_icons[service] ?? Icons.check_circle_outline, size: 18),
            label: Text(service),
            selected: selected.contains(service),
            onSelected: (on) => onToggle(service, on),
          ),
      ],
    );
  }
}
