import 'package:flutter/material.dart';

import '../../eos/widgets/financial/eos_attention_banner.dart';

class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.severity,
    required this.message,
    required this.onAction,
    this.onResolve,
    this.headline,
  });

  final String severity;
  final String message;
  final String? headline;
  final VoidCallback onAction;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    return EosAttentionBanner(
      headline: headline ?? 'Attention required',
      message: message,
      severity: severity,
      onAction: onAction,
      onDismiss: onResolve,
      actionLabel: 'View',
    );
  }
}
