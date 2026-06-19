import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';

class EosSection extends StatelessWidget {
  const EosSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.eosText.titleLarge),
                  if (subtitle != null)
                    Padding(
                      padding: EdgeInsets.only(top: context.eos.spacing.xxs),
                      child: Text(subtitle!, style: context.eosText.bodySmall),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        SizedBox(height: context.eos.spacing.sm),
        child,
        SizedBox(height: context.eos.spacing.xl),
      ],
    );
  }
}
