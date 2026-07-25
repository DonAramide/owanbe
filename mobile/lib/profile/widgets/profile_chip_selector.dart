import 'package:flutter/material.dart';

import '../../eos/eos.dart';

/// Multi-select chip / filter chip selector for interests and similar lists.
class ProfileChipSelector extends StatelessWidget {
  const ProfileChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.title,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: enabled
                    ? (isSelected) {
                        final next = {...selected};
                        if (isSelected) {
                          next.add(option);
                        } else {
                          next.remove(option);
                        }
                        onChanged(next);
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}
