import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import 'eos_adaptive.dart';

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
        EosAdaptiveActionBar(
          leading: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.eosText.titleLarge, softWrap: true),
              if (subtitle != null)
                Padding(
                  padding: EdgeInsets.only(top: context.eos.spacing.xxs),
                  child: Text(subtitle!, style: context.eosText.bodySmall, softWrap: true),
                ),
            ],
          ),
          actions: trailing != null ? [trailing!] : const [],
        ),
        SizedBox(height: context.eos.spacing.sm),
        child,
        SizedBox(height: context.eos.spacing.xl),
      ],
    );
  }
}
