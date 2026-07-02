import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_spacing.dart';
import 'workspace_definition.dart';
import 'workspace_state.dart';
import 'workspace_widgets.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.definition,
    required this.entityId,
    required this.name,
    required this.logoText,
    required this.healthScore,
    required this.environment,
    required this.region,
    required this.primaryContact,
    required this.createdDate,
    required this.lastActivity,
    this.sidebarWidgets = const [],
  });

  final WorkspaceDefinition definition;
  final String entityId;
  final String name;
  final String logoText;
  final int healthScore;
  final String environment;
  final String region;
  final String primaryContact;
  final String createdDate;
  final String lastActivity;
  final List<Widget> sidebarWidgets;

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.definition.tabs.length, vsync: this);

    // Initialize breadcrumbs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workspaceNavigationProvider.notifier).reset(
            WorkspaceNavigationItem(
              name: widget.name,
              entityType: widget.definition.entityType,
              entityId: widget.entityId,
            ),
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breadcrumbs = ref.watch(workspaceNavigationProvider);
    final drawers = ref.watch(contextDrawerProvider);

    return Scaffold(
      body: Column(
        children: [
          // 1. Breadcrumbs Ribbon
          if (breadcrumbs.isNotEmpty) _buildBreadcrumbs(context, breadcrumbs),

          // 2. Executive Header
          WorkspaceEntityHeader(
            logoText: widget.logoText,
            name: widget.name,
            entityType: widget.definition.entityType,
            plan: 'Enterprise',
            environment: widget.environment,
            region: widget.region,
            primaryContact: widget.primaryContact,
            createdDate: widget.createdDate,
            lastActivity: widget.lastActivity,
            healthScore: widget.healthScore,
            hasActiveAlerts: widget.healthScore < 75,
          ),

          // 3. Tab Navigation bar
          Material(
            color: context.eosColors.surface,
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  for (final tab in widget.definition.tabs) Tab(text: tab.label),
                ],
              ),
            ),
          ),

          // 4. Content Area + Sidebars + Context Drawers
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (final tab in widget.definition.tabs)
                        tab.builder(context, widget.entityId),
                    ],
                  ),
                ),

                // Sliding Context Drawer
                if (drawers.isNotEmpty)
                  _buildContextDrawerHost(context, drawers),

                // Persistent Sidebar Quick Actions & Meta items
                if (widget.sidebarWidgets.isNotEmpty || widget.definition.quickActions.isNotEmpty)
                  WorkspaceSidebar(
                    items: [
                      if (widget.definition.quickActions.isNotEmpty) ...[
                        Text('Quick Actions', style: context.eosText.titleSmall),
                        const SizedBox(height: 8),
                        for (final act in widget.definition.quickActions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: FilledButton.icon(
                              onPressed: () => act.onPressed(context, widget.entityId),
                              icon: Icon(act.icon, size: 14),
                              label: Text(act.label),
                              style: act.isDanger
                                  ? FilledButton.styleFrom(backgroundColor: context.eosColors.error)
                                  : null,
                            ),
                          ),
                        const Divider(height: 24),
                      ],
                      ...widget.sidebarWidgets,
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, List<WorkspaceNavigationItem> items) {
    return Container(
      width: double.infinity,
      color: context.eosColors.surfaceVariant.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              ref.read(contextDrawerProvider.notifier).clear();
              context.go('/super-admin');
            },
            child: Text('PLATFORM',
                style: context.eosText.labelSmall?.copyWith(color: context.eosColors.primary)),
          ),
          for (final item in items) ...[
            const Icon(Icons.chevron_right, size: 14),
            Text(item.name.toUpperCase(), style: context.eosText.labelSmall),
          ],
        ],
      ),
    );
  }

  Widget _buildContextDrawerHost(BuildContext context, List<ContextDrawerState> drawers) {
    final topDrawer = drawers.last;
    return Container(
      width: 440,
      decoration: BoxDecoration(
        color: context.eosColors.surface,
        border: Border(left: BorderSide(color: context.eosColors.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drawer Nav Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
            ),
            child: Row(
              children: [
                if (drawers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => ref.read(contextDrawerProvider.notifier).pop(),
                    tooltip: 'Back',
                  ),
                Text(topDrawer.title, style: context.eosText.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(contextDrawerProvider.notifier).clear(),
                  tooltip: 'Close Drawer',
                ),
              ],
            ),
          ),
          Expanded(child: topDrawer.child),
        ],
      ),
    );
  }
}
