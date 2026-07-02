import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../providers/customer_workspace_reminders_providers.dart';

import '../../widgets/workspace/customer_workspace_reminders_panel.dart';

import '../event_module_registry.dart';



/// Planning reminders built from Customer Event OS command center data.

class EventWorkspaceReminders extends ConsumerWidget {

  const EventWorkspaceReminders({super.key, required this.eventId});



  final String eventId;



  void _onNavigateTab(BuildContext context, String tabKey) {

    EventModuleRegistry.openLegacyTab(context, eventId, tabKey);

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final snapAsync = ref.watch(customerWorkspaceRemindersProvider(eventId));



    return snapAsync.when(

      loading: () => const SizedBox.shrink(),

      error: (_, _) => const SizedBox.shrink(),

      data: (snap) => CustomerWorkspaceRemindersPanel(

        reminders: snap.reminders,

        daysUntil: snap.daysUntilEvent,

        onNavigateTabKey: (tabKey) => _onNavigateTab(context, tabKey),

      ),

    );

  }

}

