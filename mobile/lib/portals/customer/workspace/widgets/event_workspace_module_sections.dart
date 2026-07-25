import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/command_center_models.dart';
import '../event_module_registry.dart';

/// Registry-driven module sections for [EventDesktop].
class EventWorkspaceModuleSections extends StatelessWidget {
  const EventWorkspaceModuleSections({
    super.key,
    required this.eventId,
    required this.snapshot,
    List<EventDesktopSection>? sections,
  })  : _sections = sections;

  final String eventId;
  final EventCommandCenterSnapshot snapshot;
  final List<EventDesktopSection>? _sections;

  @override
  Widget build(BuildContext context) {
    final sections = _sections ??
        EventModuleRegistry.desktopSections(snapshot.event, snapshot);
    final columns = EosResponsive.columnsFor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          EosSection(
            title: section.title,
            subtitle: section.subtitle,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth =
                    (constraints.maxWidth - (columns - 1) * context.eos.spacing.sm) / columns;
                return Wrap(
                  spacing: context.eos.spacing.sm,
                  runSpacing: context.eos.spacing.sm,
                  children: [
                    for (final module in section.modules)
                      SizedBox(
                        width: columns == 1 ? double.infinity : tileWidth,
                        child: _ModuleTile(
                          module: module,
                          badge: module.badgeCount?.call(snapshot),
                          onTap: () => module.onOpen(context, eventId),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
        ],
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.onTap,
    this.badge,
  });

  final EventModuleDefinition module;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: module.title,
      child: EosSurfaceCard(
        onTap: onTap,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: context.eos.spacing.md,
            vertical: context.eos.spacing.xs,
          ),
          leading: Icon(module.icon, color: EosColors.plum),
          title: Text(module.title, style: context.eosText.titleSmall),
          subtitle: Text(module.subtitle, style: context.eosText.bodySmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null)
                Padding(
                  padding: EdgeInsets.only(right: context.eos.spacing.xs),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: EosColors.plum,
                    child: Text(
                      badge! > 99 ? '99+' : '$badge',
                      style: context.eosText.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: context.eosColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consolidated quick actions derived from the module registry.
class EventWorkspaceQuickActions extends StatelessWidget {
  const EventWorkspaceQuickActions({
    super.key,
    required this.eventId,
    required this.snapshot,
  });

  final String eventId;
  final EventCommandCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final modules = EventModuleRegistry.quickActionModules(snapshot.event, snapshot);
    if (modules.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        for (final module in modules)
          OutlinedButton.icon(
            onPressed: () => module.onOpen(context, eventId),
            icon: Icon(module.icon, size: 18),
            label: Text(module.title),
          ),
      ],
    );
  }
}
