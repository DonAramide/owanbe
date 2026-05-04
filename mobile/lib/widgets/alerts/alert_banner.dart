import 'package:flutter/material.dart';

class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.severity,
    required this.message,
    required this.onAction,
    this.onResolve,
  });
  final String severity;
  final String message;
  final VoidCallback onAction;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity.toUpperCase()) {
      'CRITICAL' => Colors.red,
      'WARNING' => Colors.orange,
      _ => Colors.blueGrey,
    };
    return Card(
      color: color.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(Icons.warning_rounded, color: color),
        title: Text(message),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (onResolve != null) TextButton(onPressed: onResolve, child: const Text('Resolve')),
            TextButton(onPressed: onAction, child: const Text('View')),
          ],
        ),
      ),
    );
  }
}
