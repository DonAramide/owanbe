import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/event_website_models.dart';

/// Structured template preview — mobile or desktop frame.
class EventWebsitePreviewFrame extends StatelessWidget {
  const EventWebsitePreviewFrame({
    super.key,
    required this.config,
    required this.compact,
  });

  final EventWebsiteConfig config;
  final bool compact;

  Color get _accent {
    try {
      final hex = config.themeColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return EosColors.plum;
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = EventWebsiteTemplate.gallery.firstWhere(
      (t) => t.id == config.templateId,
      orElse: () => EventWebsiteTemplate.gallery.first,
    );
    final enabledSections = EventWebsiteSectionKeys.all
        .where((k) => config.sections[k] == true)
        .map((k) => EventWebsiteSectionKeys.labels[k]!)
        .toList();

    return Container(
      width: compact ? 280 : double.infinity,
      constraints: BoxConstraints(maxWidth: compact ? 280 : 720),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: EosRadius.card,
        border: Border.all(color: context.eosColors.outlineVariant),
        boxShadow: context.eos.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: compact ? 120 : 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accent, _accent.withValues(alpha: 0.75)],
              ),
            ),
            padding: EdgeInsets.all(compact ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(template.icon, style: TextStyle(fontSize: compact ? 20 : 28)),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  config.eventTitle,
                  style: (compact ? context.eosText.titleMedium : context.eosText.headlineSmall)
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  template.label,
                  style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sections', style: context.eosText.labelLarge),
                SizedBox(height: context.eos.spacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: enabledSections
                      .map(
                        (label) => Chip(
                          label: Text(label, style: context.eosText.labelSmall),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _accent.withValues(alpha: 0.08),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  'Font: ${EventWebsiteFontPairs.options.firstWhere((p) => p.$1 == config.fontPair, orElse: () => EventWebsiteFontPairs.options.first).$2}',
                  style: context.eosText.bodySmall,
                ),
                if (config.isPublished) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  Row(
                    children: [
                      Icon(Icons.link, size: 14, color: _accent),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          config.publicUrl,
                          style: context.eosText.bodySmall?.copyWith(color: _accent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
