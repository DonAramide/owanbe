import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/event_navigator.dart';
import '../workspace/event_module_scaffold.dart';

/// Thin Event OS wrapper for existing live-ops screens (Phase 4).
class CustomerEventOpsModuleScreen extends ConsumerWidget {
  const CustomerEventOpsModuleScreen({
    super.key,
    required this.eventId,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
  });

  final String eventId;
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EventModuleScaffold(
      eventId: eventId,
      title: title,
      subtitle: subtitle,
      actions: actions,
      body: body,
    );
  }
}
