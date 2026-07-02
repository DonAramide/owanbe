import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

/// Inline busy indicator for Event OS module actions (Phase 42.6).
///
/// Replaces ad-hoc [CircularProgressIndicator] in app bars and buttons.
class EventModuleBusyIndicator extends StatelessWidget {
  const EventModuleBusyIndicator({
    super.key,
    this.size = 20,
    this.onLightBackground = true,
  });

  const EventModuleBusyIndicator.onButton({super.key})
      : size = 18,
        onLightBackground = false;

  final double size;
  final bool onLightBackground;

  @override
  Widget build(BuildContext context) {
    final color = onLightBackground
        ? context.eosColors.primary
        : context.eosColors.onPrimary;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

/// App-bar action slot while a module action is in progress.
class EventModuleBusyAction extends StatelessWidget {
  const EventModuleBusyAction({super.key, required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (!busy) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.all(16),
      child: EventModuleBusyIndicator(),
    );
  }
}
