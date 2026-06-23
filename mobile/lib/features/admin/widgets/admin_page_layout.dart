import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Desktop-first admin page chrome with 24px grid padding.
class AdminPageLayout extends StatelessWidget {
  const AdminPageLayout({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.header,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(EosSpacing.lg, EosSpacing.lg, EosSpacing.lg, EosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.eosText.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                          if (subtitle != null) ...[
                            SizedBox(height: context.eos.spacing.xs),
                            Text(
                              subtitle!,
                              style: context.eosText.bodyLarge?.copyWith(
                                color: context.eosColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
                if (header != null) ...[
                  SizedBox(height: context.eos.spacing.lg),
                  header!,
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(EosSpacing.lg, 0, EosSpacing.lg, EosSpacing.xxl),
          sliver: SliverToBoxAdapter(child: body),
        ),
      ],
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EosSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!, style: context.eosText.bodySmall?.copyWith(color: context.eosColors.onSurfaceVariant)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AdminKpiGrid extends StatelessWidget {
  const AdminKpiGrid({super.key, required this.children, this.minTileWidth = 200});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / minTileWidth).floor().clamp(1, 6);
        final tileWidth = (constraints.maxWidth - (cols - 1) * EosSpacing.lg) / cols;
        return Wrap(
          spacing: EosSpacing.lg,
          runSpacing: EosSpacing.lg,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
