import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import 'event_friendly_errors.dart';

/// Shared friendly error surface for Event OS modules (Phase 42.4 / 42.6).
class EventErrorView extends StatefulWidget {
  const EventErrorView({
    super.key,
    required this.headline,
    required this.message,
    this.icon = Icons.cloud_off_outlined,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.onSecondary,
    this.secondaryLabel,
    this.diagnosticId,
  });

  factory EventErrorView.module({
    required String moduleLabel,
    VoidCallback? onRetry,
    VoidCallback? onBackToOverview,
    String backLabel = 'Back to workspace',
    Object? error,
  }) {
    return EventErrorView(
      headline: EventFriendlyErrors.headlineFor(moduleLabel),
      message: EventFriendlyErrors.messageFor(moduleLabel),
      onRetry: onRetry,
      onSecondary: onBackToOverview,
      secondaryLabel: onBackToOverview != null ? backLabel : null,
      diagnosticId: error?.toString(),
    );
  }

  factory EventErrorView.workspace({
    VoidCallback? onRetry,
    VoidCallback? onBackToEvents,
    Object? error,
  }) {
    return EventErrorView(
      headline: EventFriendlyErrors.workspaceHeadline,
      message: EventFriendlyErrors.workspaceMessage,
      icon: Icons.celebration_outlined,
      onRetry: onRetry,
      onSecondary: onBackToEvents,
      secondaryLabel: onBackToEvents != null ? 'Back to my events' : null,
      diagnosticId: error?.toString(),
    );
  }

  final String headline;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final String? diagnosticId;

  @override
  State<EventErrorView> createState() => _EventErrorViewState();
}

class _EventErrorViewState extends State<EventErrorView> {
  var _showDiagnostics = false;

  @override
  Widget build(BuildContext context) {
    final showDebugDetails = kDebugMode && widget.diagnosticId != null;

    return Semantics(
      label: '${widget.headline}. ${widget.message}',
      child: EosSurfaceCard(
        elevated: true,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.eos.spacing.md),
          child: Column(
            children: [
              Icon(
                widget.icon,
                size: 48,
                color: context.eosColors.primary.withValues(alpha: 0.85),
              ),
              SizedBox(height: context.eos.spacing.md),
              Text(
                widget.headline,
                textAlign: TextAlign.center,
                style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: context.eos.spacing.xs),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: context.eosText.bodyMedium?.copyWith(
                  color: context.eosColors.onSurfaceVariant,
                ),
              ),
              if (widget.onRetry != null || widget.onSecondary != null) ...[
                SizedBox(height: context.eos.spacing.lg),
                if (widget.onRetry != null)
                  FilledButton(onPressed: widget.onRetry, child: Text(widget.retryLabel)),
                if (widget.onSecondary != null && widget.secondaryLabel != null) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  TextButton(onPressed: widget.onSecondary, child: Text(widget.secondaryLabel!)),
                ],
              ],
              if (showDebugDetails) ...[
                SizedBox(height: context.eos.spacing.sm),
                TextButton(
                  onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
                  child: Text(_showDiagnostics ? 'Hide details' : 'Technical details'),
                ),
                if (_showDiagnostics)
                  Padding(
                    padding: EdgeInsets.only(top: context.eos.spacing.xs),
                    child: Text(
                      widget.diagnosticId!,
                      textAlign: TextAlign.center,
                      style: context.eosText.labelSmall?.copyWith(
                        color: context.eosColors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
