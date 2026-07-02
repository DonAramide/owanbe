import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import '../tokens/eos_spacing.dart';
import '../widgets/cards/eos_surface_card.dart';

/// Premium Executive Header for Owambe 360 Workspace Architecture.
class EosWorkspaceHeader extends StatelessWidget {
  const EosWorkspaceHeader({
    super.key,
    required this.name,
    required this.logoText,
    required this.businessType,
    required this.plan,
    required this.environment,
    required this.region,
    required this.primaryContact,
    required this.createdDate,
    required this.lastActivity,
    required this.healthScore,
    this.hasActiveAlerts = false,
    this.onBack,
  });

  final String name;
  final String logoText;
  final String businessType;
  final String plan;
  final String environment;
  final String region;
  final String primaryContact;
  final String createdDate;
  final String lastActivity;
  final int healthScore;
  final bool hasActiveAlerts;
  final VoidCallback? onBack;

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
              if (onBack != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
              ],
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
                    Text('$businessType · Region: $region · Primary: $primaryContact',
                        style: context.eosText.bodySmall),
                  ],
                ),
              ),
              // Health Indicator
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
          // Metadata bar
          Row(
            children: [
              _buildMetaItem(context, 'Created On', createdDate),
              _buildVerticalDivider(context),
              _buildMetaItem(context, 'Last Activity', lastActivity),
              _buildVerticalDivider(context),
              _buildMetaItem(context, 'Infrastructure', 'AWS-eu-west-1 (Shared RDS)'),
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

/// Persistent Quick Actions Sidebar.
class EosWorkspaceQuickActions extends StatelessWidget {
  const EosWorkspaceQuickActions({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: context.eosColors.outlineVariant)),
        color: context.eosColors.surfaceVariant.withOpacity(0.2),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => actions[index],
      ),
    );
  }
}

/// Generic KPI Strip widget with interactive taps.
class EosWorkspaceKpiStrip extends StatelessWidget {
  const EosWorkspaceKpiStrip({
    super.key,
    required this.kpis,
  });

  final List<Widget> kpis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          Expanded(child: kpis[i]),
          if (i < kpis.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

/// Expandable Context Side Drawer to display details on the same page.
class EosWorkspaceContextDrawer extends StatelessWidget {
  const EosWorkspaceContextDrawer({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: context.eosColors.surface,
        border: Border(left: BorderSide(color: context.eosColors.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
            ),
            child: Row(
              children: [
                Text(title, style: context.eosText.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Reusable Workspace Timeline element.
class EosWorkspaceTimeline extends StatelessWidget {
  const EosWorkspaceTimeline({
    super.key,
    required this.items,
  });

  final List<EosWorkspaceTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No timeline activity recorded'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
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
                  if (index < items.length - 1)
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
    );
  }
}

class EosWorkspaceTimelineItem {
  const EosWorkspaceTimelineItem({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final String description;
  final String timestamp;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
}

/// Alert and Notification Panel for the Overview dashboard.
class EosWorkspaceAlertPanel extends StatelessWidget {
  const EosWorkspaceAlertPanel({
    super.key,
    required this.alerts,
  });

  final List<EosWorkspaceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final alert in alerts) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: alert.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: alert.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(alert.icon, color: alert.color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.headline, style: context.eosText.titleSmall?.copyWith(color: alert.color)),
                      const SizedBox(height: 2),
                      Text(alert.message, style: context.eosText.bodySmall),
                    ],
                  ),
                ),
                if (alert.onAction != null)
                  TextButton(
                    onPressed: alert.onAction,
                    child: Text(alert.actionLabel ?? 'Resolve'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class EosWorkspaceAlert {
  const EosWorkspaceAlert({
    required this.headline,
    required this.message,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  final String headline;
  final String message;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
}
