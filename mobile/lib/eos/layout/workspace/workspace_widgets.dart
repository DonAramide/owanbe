import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_spacing.dart';
import '../../widgets/cards/eos_surface_card.dart';
import 'entity_engine.dart';
import 'workspace_definition.dart';
import 'workspace_state.dart';

class WorkspaceEntityHeader extends StatelessWidget {
  const WorkspaceEntityHeader({
    super.key,
    required this.logoText,
    required this.name,
    required this.entityType,
    required this.plan,
    required this.environment,
    required this.region,
    required this.primaryContact,
    required this.createdDate,
    required this.lastActivity,
    required this.healthScore,
    this.hasActiveAlerts = false,
  });

  final String logoText;
  final String name;
  final WorkspaceEntityType entityType;
  final String plan;
  final String environment;
  final String region;
  final String primaryContact;
  final String createdDate;
  final String lastActivity;
  final int healthScore;
  final bool hasActiveAlerts;

  @override
  Widget build(BuildContext context) {
    final statusColor = healthScore > 75
        ? Colors.green
        : (healthScore > 40 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.eosColors.surface,
        border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.eosColors.primaryContainer,
                child: Text(logoText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.eosColors.onPrimaryContainer,
                    )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: context.eosText.headlineSmall),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.eosColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(plan.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.eosColors.onSecondaryContainer,
                              )),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: environment.toLowerCase() == 'production'
                                ? Colors.green.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(environment.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: environment.toLowerCase() == 'production' ? Colors.green : Colors.blue,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (entityType == WorkspaceEntityType.security)
                      Text(
                        'Platform: Owambe Cloud Operations · Region: ${region.isNotEmpty ? region : "Unavailable"} · Runtime: v1.12.4-prod',
                        style: context.eosText.bodySmall,
                      )
                    else
                      Text(
                        '${entityType.name.toUpperCase()} · Region: ${region.isNotEmpty ? region : "Unavailable"} · Primary: ${primaryContact.isNotEmpty ? primaryContact : "Not Configured"}',
                        style: context.eosText.bodySmall,
                      ),
                  ],
                ),
              ),
              // Health Score Gauge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (hasActiveAlerts) ...[
                        const Icon(Icons.warning, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text('HEALTH INDEX', style: context.eosText.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$healthScore%',
                          style: context.eosText.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          )),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metadata items
          if (entityType == WorkspaceEntityType.security)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetaItem(context, 'Environment', environment.isNotEmpty ? environment : 'Unavailable'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Platform', 'Owambe Cloud Platform'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Region', region.isNotEmpty ? region : 'Unavailable'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Security Score', '96%'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Threat Level', 'LOW'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Last Scan', '2026-06-29 02:00:00'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Policy Update', '2026-06-28 14:22:00'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Compliance', 'NDPR, GDPR, PCI-DSS'),
                  _buildVerticalDivider(context),
                  _buildMetaItem(context, 'Runtime Version', 'v1.12.4-prod'),
                ],
              ),
            )
          else
            Row(
              children: [
                _buildMetaItem(context, 'Created On', createdDate.isNotEmpty ? createdDate : 'Unavailable'),
                _buildVerticalDivider(context),
                _buildMetaItem(context, 'Last Activity', lastActivity.isNotEmpty ? lastActivity : 'Unavailable'),
                _buildVerticalDivider(context),
                _buildMetaItem(context, 'Environment', environment.isNotEmpty ? environment : 'Unavailable'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: context.eosText.labelSmall?.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildVerticalDivider(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: context.eosColors.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}

/// Pluggable timeline with category filters.
class WorkspaceTimeline extends StatefulWidget {
  const WorkspaceTimeline({
    super.key,
    required this.items,
  });

  final List<WorkspaceTimelineItem> items;

  @override
  State<WorkspaceTimeline> createState() => _WorkspaceTimelineState();
}

class _WorkspaceTimelineState extends State<WorkspaceTimeline> {
  String _activeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((i) {
      if (_activeFilter == 'all') return true;
      return i.category.toLowerCase() == _activeFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'All Activity'),
              const SizedBox(width: 8),
              _buildFilterChip('operations', 'Operations'),
              const SizedBox(width: 8),
              _buildFilterChip('security', 'Security'),
              const SizedBox(width: 8),
              _buildFilterChip('finance', 'Financial'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const Center(child: Text('No events match the selected filter'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item.iconColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 16, color: item.iconColor),
                        ),
                        if (index < filtered.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: context.eosColors.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: InkWell(
                          onTap: item.onTap,
                          child: EosSurfaceCard(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item.title, style: context.eosText.titleSmall),
                                      Text(item.timestamp, style: context.eosText.bodySmall),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item.description, style: context.eosText.bodyMedium),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final active = _activeFilter == filter;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) => setState(() => _activeFilter = filter),
    );
  }
}

class WorkspaceTimelineItem {
  const WorkspaceTimelineItem({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.category,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final String description;
  final String timestamp;
  final String category;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
}

/// Entity Relationship Explorer mapping dynamically via EntityEngine.
class WorkspaceRelationshipGraph extends ConsumerWidget {
  const WorkspaceRelationshipGraph({
    super.key,
    required this.currentType,
    required this.entityId,
  });

  final WorkspaceEntityType currentType;
  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = EntityEngine.resolve(entityId, fallbackType: currentType);

    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relationship Explorer', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < entity.relations.length; i++) ...[
                    _buildNodeCard(context, ref, entity.relations[i]),
                    if (i < entity.relations.length - 1)
                      Icon(Icons.arrow_forward, color: context.eosColors.outline, size: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeCard(BuildContext context, WidgetRef ref, EntityRelation relation) {
    final active = relation.type == currentType;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ActionChip(
        avatar: Icon(relation.icon, size: 14, color: active ? Colors.white : context.eosColors.primary),
        label: Text(relation.label),
        backgroundColor: active ? context.eosColors.primary : null,
        labelStyle: TextStyle(color: active ? Colors.white : null),
        onPressed: () {
          EntityEngine.open(context, ref, relation.targetId, fallbackType: relation.type);
        },
      ),
    );
  }
}

/// Generic Health details panel explaining ratings reasons.
class WorkspaceHealthPanel extends StatelessWidget {
  const WorkspaceHealthPanel({
    super.key,
    required this.healthScore,
    required this.factors,
  });

  final int healthScore;
  final List<String> factors;

  @override
  Widget build(BuildContext context) {
    final statusColor = healthScore > 75
        ? Colors.green
        : (healthScore > 40 ? Colors.orange : Colors.red);

    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Health Core Metrics', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: healthScore / 100,
                        strokeWidth: 6,
                        backgroundColor: context.eosColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                    Text('$healthScore', style: context.eosText.titleLarge),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final factor in factors)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 12, color: statusColor),
                              const SizedBox(width: 8),
                              Expanded(child: Text(factor, style: context.eosText.bodySmall)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.items,
  });

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: context.eosColors.surfaceVariant.withOpacity(0.15),
        border: Border(left: BorderSide(color: context.eosColors.outlineVariant)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, idx) => items[idx],
      ),
    );
  }
}

class EosSkeletonLoader extends StatelessWidget {
  const EosSkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.eosColors.outlineVariant,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class EosSearchBar extends StatelessWidget {
  const EosSearchBar({
    super.key,
    required this.hintText,
    this.onChanged,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: context.eosColors.outlineVariant),
        ),
        filled: true,
        fillColor: context.eosColors.surfaceVariant.withOpacity(0.2),
      ),
    );
  }
}

class EosFilterBar extends StatelessWidget {
  const EosFilterBar({
    super.key,
    required this.filters,
    required this.activeFilter,
    required this.onSelected,
  });

  final List<String> filters;
  final String activeFilter;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final active = f == activeFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              selected: active,
              label: Text(f),
              onSelected: (_) => onSelected(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}
