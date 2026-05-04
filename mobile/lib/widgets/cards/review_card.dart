import 'package:flutter/material.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onApprove,
    required this.onReject,
    required this.onEscalate,
  });
  final String title;
  final String subtitle;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(onPressed: onApprove, child: const Text('Approve')),
                OutlinedButton(onPressed: onReject, child: const Text('Reject + Refund')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: onEscalate,
                  child: const Text('Escalate + Freeze'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
