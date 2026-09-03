import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../../../identity/experience_navigation.dart';
import '../../../navigation/enterprise_back_handler.dart';
import '../providers/customer_event_providers.dart';
import 'widgets/event_module_busy_indicator.dart';

/// Standard motion durations for Event OS (Phase 42.6).
abstract final class EventOsMotion {
  static const fast = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 400);
}

/// Constrains Event OS content width on tablet/desktop.
class EventResponsiveCanvas extends StatelessWidget {
  const EventResponsiveCanvas({super.key, required this.child});

  final Widget child;

  static const maxContentWidth = 1120.0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}

/// Unified page scaffold for every Event OS module (Phase 42.4+ / 42.6).
class EventModuleScaffold extends ConsumerWidget {
  const EventModuleScaffold({
    super.key,
    required this.eventId,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.endDrawer,
    this.floatingActionButton,
    this.scaffoldKey,
    this.appBarBottom,
    this.footer,
    this.busy = false,
    this.showBreadcrumb = true,
    this.onBack,
  });

  final String eventId;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? appBarBottom;
  final Widget? footer;
  final bool busy;
  final bool showBreadcrumb;
  final Future<void> Function()? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventName = ref.watch(
      customerEventProvider(eventId).select((async) => async.valueOrNull?.title),
    );

    final appBarActions = <Widget>[
      if (busy) const EventModuleBusyAction(busy: true),
      ...?actions,
    ];

    return WorkspaceBackScope(
      child: Scaffold(
        key: scaffoldKey,
        endDrawer: endDrawer,
        floatingActionButton: floatingActionButton,
        appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          tooltip: 'Back',
          onPressed: () async {
            if (onBack != null) {
              await onBack!();
            } else {
              ExperienceNavigation.navigateBack(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBreadcrumb && eventName != null) ...[
              _EventBreadcrumb(eventTitle: eventName, moduleTitle: title),
              SizedBox(height: context.eos.spacing.xxs),
            ],
            Text(title, style: context.eosText.titleMedium),
            if (subtitle != null)
              Text(
                subtitle!,
                style: context.eosText.labelSmall?.copyWith(
                  color: context.eosColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: appBarActions.isEmpty ? null : appBarActions,
        bottom: appBarBottom,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: EventResponsiveCanvas(child: body)),
            if (footer != null) footer!,
          ],
        ),
      ),
      ),
    );
  }
}

class _EventBreadcrumb extends StatelessWidget {
  const _EventBreadcrumb({required this.eventTitle, required this.moduleTitle});

  final String eventTitle;
  final String moduleTitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Event $eventTitle, module $moduleTitle',
      child: Text(
        eventTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.eosText.labelSmall?.copyWith(
          color: context.eosColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Standard scroll body for event modules with consistent section rhythm.
class EventModuleScrollBody extends StatelessWidget {
  const EventModuleScrollBody({
    super.key,
    required this.content,
    this.hero,
    this.primaryKpi,
    this.activity,
    this.quickActions,
    this.onRefresh,
  });

  final Widget? hero;
  final Widget? primaryKpi;
  final Widget content;
  final Widget? activity;
  final Widget? quickActions;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: EosSpacing.pagePadding.copyWith(bottom: EosSpacing.xxxl),
      children: [
        if (hero != null) ...[hero!, SizedBox(height: context.eos.spacing.lg)],
        if (primaryKpi != null) ...[primaryKpi!, SizedBox(height: context.eos.spacing.lg)],
        content,
        if (activity != null) ...[
          SizedBox(height: context.eos.spacing.lg),
          activity!,
        ],
        if (quickActions != null) ...[
          SizedBox(height: context.eos.spacing.lg),
          quickActions!,
        ],
      ],
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
