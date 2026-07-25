import 'package:flutter/material.dart';

import '../../../identity/experience_navigation.dart';import '../../../eos/eos.dart';
import '../../../features/workspace/widgets/workspace_experience_shell.dart';
import '../../../identity/workspace_models.dart';
import 'attendee_top_bar.dart';

/// Shared chrome for attendee sub-routes (event detail, tickets, checkout).
class AttendeeFlowScaffold extends StatelessWidget {
  const AttendeeFlowScaffold({
    super.key,
    required this.body,
    this.backLabel = 'Back',
    this.onBack,
  });

  final Widget body;
  final String backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return WorkspaceExperienceShell(
      workspace: ExperienceWorkspace.attendee,
      child: Scaffold(
        backgroundColor: context.eosColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AttendeeTopBar(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBack ?? () => _defaultBack(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(backLabel),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  void _defaultBack(BuildContext context) {
    ExperienceNavigation.navigateBack(context);
  }
}
