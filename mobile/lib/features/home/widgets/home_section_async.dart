import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Reusable loading / error / retry shell for independent home sections.
class HomeSectionLoading extends StatelessWidget {
  const HomeSectionLoading({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: EosColors.champagne),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Text(
              title ?? 'Loading…',
              style: context.eosText.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSectionError extends StatelessWidget {
  const HomeSectionError({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.xs),
          Text(message, style: context.eosText.bodySmall),
          if (onRetry != null) ...[
            SizedBox(height: context.eos.spacing.md),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

