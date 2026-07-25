import 'package:flutter/material.dart';

import '../../../eos/eos.dart';
import '../../../identity/workspace_models.dart';

/// Premium workspace launcher card — primary hub entry point.
class WorkspaceExperienceCard extends StatelessWidget {
  const WorkspaceExperienceCard({
    super.key,
    required this.workspace,
    required this.state,
    required this.onPressed,
    this.compact = false,
    this.isLastOpened = false,
  });

  final ExperienceWorkspace workspace;
  final WorkspaceState state;
  final VoidCallback onPressed;
  final bool compact;
  final bool isLastOpened;

  static const _accent = <ExperienceWorkspace, Color>{
    ExperienceWorkspace.attendee: Color(0xFF7B1FA2),
    ExperienceWorkspace.organizer: Color(0xFF4A148C),
    ExperienceWorkspace.vendor: Color(0xFF6A1B9A),
  };

  IconData get _icon => switch (workspace) {
        ExperienceWorkspace.attendee => Icons.confirmation_number_outlined,
        ExperienceWorkspace.organizer => Icons.celebration_outlined,
        ExperienceWorkspace.vendor => Icons.storefront_outlined,
      };

  String get _launcherDescription => switch (workspace) {
        ExperienceWorkspace.attendee =>
          'Discover and attend unforgettable experiences.',
        ExperienceWorkspace.organizer =>
          'Create and manage exceptional events.',
        ExperienceWorkspace.vendor =>
          'Grow your business by serving event organizers.',
      };

  String get _statusLabel => switch (state.status) {
        WorkspaceStatus.active => 'Verified',
        WorkspaceStatus.inProgress => 'In Progress',
        WorkspaceStatus.notActivated => 'Not Activated',
        WorkspaceStatus.suspended => 'Suspended',
      };

  String get _actionLabel => switch (state.status) {
        WorkspaceStatus.active => 'Enter Workspace',
        WorkspaceStatus.inProgress => 'Continue Setup',
        WorkspaceStatus.notActivated => 'Activate Workspace',
        WorkspaceStatus.suspended => 'Contact Support',
      };

  Color get _statusColor => switch (state.status) {
        WorkspaceStatus.active => Colors.greenAccent,
        WorkspaceStatus.inProgress => EosColors.champagne,
        WorkspaceStatus.notActivated => Colors.white54,
        WorkspaceStatus.suspended => Colors.redAccent,
      };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildPremium(context);
  }

  Widget _buildPremium(BuildContext context) {
    final accent = _accent[workspace] ?? EosColors.plum;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.55),
                EosColors.plumDark.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: isLastOpened
                  ? EosColors.champagne.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.12),
              width: isLastOpened ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_icon, color: EosColors.champagne, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workspace.title,
                            style: context.eosText.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (isLastOpened)
                            Text(
                              'Last opened',
                              style: context.eosText.labelSmall?.copyWith(
                                color: EosColors.champagne,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _StatusPill(label: _statusLabel, color: _statusColor),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _launcherDescription,
                  style: context.eosText.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
                if (state.status == WorkspaceStatus.inProgress &&
                    state.profileCompletionPct > 0) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: state.profileCompletionPct / 100,
                    backgroundColor: Colors.white12,
                    color: EosColors.champagne,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${state.profileCompletionPct}% complete',
                    style: context.eosText.bodySmall?.copyWith(color: Colors.white60),
                  ),
                ],
                if (state.status == WorkspaceStatus.active) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 16, color: Colors.greenAccent.shade200),
                      const SizedBox(width: 6),
                      Text(
                        'Ready to enter',
                        style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: state.isActive ? EosColors.champagne : null,
                      foregroundColor: state.isActive ? EosColors.plumDark : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(_icon, color: EosColors.champagne, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.title,
                      style: context.eosText.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (isLastOpened)
                      Text(
                        'Last opened',
                        style: context.eosText.labelSmall?.copyWith(color: EosColors.champagne),
                      ),
                  ],
                ),
              ),
              _StatusPill(label: _statusLabel, color: _statusColor, small: true),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.small = false,
  });

  final String label;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
