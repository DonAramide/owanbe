import 'package:flutter/material.dart';

import '../auth_error_messages.dart';

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.error});

  final AuthErrorMessage error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final surface = errorColor.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: errorColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          if (error.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'What you can do',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final step in error.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: theme.textTheme.bodySmall),
                    Expanded(child: Text(step, style: theme.textTheme.bodySmall?.copyWith(height: 1.4))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
