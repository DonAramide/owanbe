import 'package:flutter/material.dart';

import '../../../eos/eos.dart';
import 'admin_nav.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.extended,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 260 : 72,
      decoration: BoxDecoration(
        color: context.eosColors.surface,
        border: Border(right: BorderSide(color: context.eosColors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? EosSpacing.lg : EosSpacing.md,
              EosSpacing.lg,
              EosSpacing.md,
              EosSpacing.lg,
            ),
            child: extended
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Owanbe', style: context.eosText.titleLarge?.copyWith(color: EosColors.plum, fontWeight: FontWeight.w800)),
                      SizedBox(height: context.eos.spacing.xxs),
                      Text('Platform Admin', style: context.eosText.labelSmall?.copyWith(color: context.eosColors.onSurfaceVariant)),
                    ],
                  )
                : Icon(Icons.shield_outlined, color: context.eosColors.primary, size: 28),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: EosSpacing.sm),
              children: [
                for (var i = 0; i < adminNavItems.length; i++)
                  _SidebarTile(
                    item: adminNavItems[i],
                    selected: selectedIndex == i,
                    extended: extended,
                    onTap: () => onSelected(i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.eosColors.primaryContainer.withValues(alpha: 0.55) : Colors.transparent;
    final fg = selected ? context.eosColors.primary : context.eosColors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: EosSpacing.xs),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? EosSpacing.md : EosSpacing.sm,
              vertical: EosSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(selected ? (item.selectedIcon ?? item.icon) : item.icon, size: 22, color: fg),
                if (extended) ...[
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(
                    child: Text(
                      item.label,
                      style: context.eosText.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
