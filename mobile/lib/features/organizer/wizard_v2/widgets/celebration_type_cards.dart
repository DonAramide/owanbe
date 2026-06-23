import 'package:flutter/material.dart';

import '../../../../core/api/event_config_api.dart';
import '../../../../eos/eos.dart';

class CelebrationTypeCards extends StatelessWidget {
  const CelebrationTypeCards({
    super.key,
    required this.categories,
    required this.selectedSlug,
    required this.onSelected,
  });

  final List<EventCategoryConfig> categories;
  final String? selectedSlug;
  final ValueChanged<EventCategoryConfig> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxis = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            mainAxisSpacing: context.eos.spacing.md,
            crossAxisSpacing: context.eos.spacing.md,
            childAspectRatio: 1.05,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final selected = cat.slug == selectedSlug;
            return _CelebrationCard(
              label: cat.label,
              icon: _iconFor(cat.iconKey),
              selected: selected,
              onTap: () => onSelected(cat),
            );
          },
        );
      },
    );
  }

  IconData _iconFor(String key) => switch (key) {
        'heart' => Icons.favorite_outline,
        'cake' => Icons.cake_outlined,
        'child' || 'child_care' => Icons.child_care_outlined,
        'business' => Icons.business_center_outlined,
        'festival' => Icons.celebration_outlined,
        'groups' => Icons.groups_outlined,
        _ => Icons.auto_awesome_outlined,
      };
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? EosColors.champagne.withValues(alpha: 0.35) : EosColors.surface,
      elevation: selected ? 2 : 0,
      shadowColor: EosColors.plum.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? EosColors.plum : EosColors.slate300.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
          ),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: EosColors.plum),
              SizedBox(height: context.eos.spacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
