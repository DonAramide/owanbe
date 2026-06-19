import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import '../tokens/eos_spacing.dart';

/// Standard page chrome: title, optional actions, padded scroll body.
class EosPageScaffold extends StatelessWidget {
  const EosPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.leading,
    this.floatingHeader,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingHeader;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EosSpacing.pagePadding.copyWith(bottom: EosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, SizedBox(height: context.eos.spacing.sm)],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.eosText.headlineMedium),
                          if (subtitle != null) ...[
                            SizedBox(height: context.eos.spacing.xs),
                            Text(subtitle!, style: context.eosText.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
                if (floatingHeader != null) ...[
                  SizedBox(height: context.eos.spacing.md),
                  floatingHeader!,
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EosSpacing.pagePadding.copyWith(top: 0),
          sliver: SliverToBoxAdapter(child: body),
        ),
      ],
    );
  }
}
