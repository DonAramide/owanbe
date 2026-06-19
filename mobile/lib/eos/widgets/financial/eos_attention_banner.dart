import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';
import '../cards/eos_surface_card.dart';

class EosAttentionBanner extends StatelessWidget {
  const EosAttentionBanner({
    super.key,
    required this.headline,
    required this.message,
    this.severity = 'WARNING',
    this.onAction,
    this.actionLabel = 'View',
    this.onDismiss,
  });

  final String headline;
  final String message;
  final String severity;
  final VoidCallback? onAction;
  final String actionLabel;
  final VoidCallback? onDismiss;

  Color get _color => switch (severity.toUpperCase()) {
        'CRITICAL' => EosColors.critical,
        'WARNING' => EosColors.warning,
        _ => EosColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: EosSurfaceCard(
        accentColor: color,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: color, size: 22),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: context.eosText.titleSmall?.copyWith(color: color)),
                  SizedBox(height: context.eos.spacing.xxs),
                  Text(message, style: context.eosText.bodySmall),
                  if (onAction != null) ...[
                    SizedBox(height: context.eos.spacing.xs),
                    TextButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(onPressed: onDismiss, icon: const Icon(Icons.close, size: 18)),
          ],
        ),
      ),
    );
  }
}
