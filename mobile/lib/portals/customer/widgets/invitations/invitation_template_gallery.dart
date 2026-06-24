import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../../../features/organizer/models/organizer_models.dart';
import '../../models/invitation_template_models.dart';
import '../../models/home_hub_models.dart';
import 'invitation_card_renderer.dart';

class InvitationTemplateGallery extends StatelessWidget {
  const InvitationTemplateGallery({
    super.key,
    required this.event,
    required this.selectedId,
    required this.onSelected,
  });

  final OrganizerEvent event;
  final String selectedId;
  final ValueChanged<InvitationTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tier in InvitationTemplateTier.values) ...[
          Row(
            children: [
              Text(tier.label, style: context.eosText.titleSmall),
              SizedBox(width: context.eos.spacing.sm),
              if (tier != InvitationTemplateTier.standard)
                Chip(
                  label: Text(tier == InvitationTemplateTier.threeD ? 'Add-on from ₦15,000' : 'Add-on from ₦35,000'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: templatesForTier(tier).length,
              separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.sm),
              itemBuilder: (context, index) {
                final template = templatesForTier(tier)[index];
                final selected = template.id == selectedId;
                return _TemplateThumb(
                  template: template,
                  event: event,
                  selected: selected,
                  onTap: () => onSelected(template),
                );
              },
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
        ],
      ],
    );
  }
}

class InvitationTemplatePreview extends StatelessWidget {
  const InvitationTemplatePreview({
    super.key,
    required this.event,
    required this.template,
  });

  final OrganizerEvent event;
  final InvitationTemplate template;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: InvitationCardRenderer(
              template: template,
              event: event,
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Row(
            children: [
              Expanded(child: Text(template.name, style: context.eosText.titleSmall)),
              if (template.isPremium) _TierPill(template: template),
            ],
          ),
          Text(template.description, style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            '${formatEventDate(event.startsAt)} · ${event.venue}, ${event.city}',
            style: context.eosText.bodySmall,
          ),
          if (event.celebrantImageUrl == null || event.celebrantImageUrl!.isEmpty) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text(
              'Tip: Add a celebrant photo when creating the event to personalize this card.',
              style: context.eosText.labelMedium?.copyWith(color: EosColors.plum),
            ),
          ],
          if (template.priceMinor > 0) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text(
              'Template add-on: ${formatRevenue(template.priceMinor)} (billed when you send)',
              style: context.eosText.labelMedium?.copyWith(color: EosColors.plum),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateThumb extends StatelessWidget {
  const _TemplateThumb({
    required this.template,
    required this.event,
    required this.selected,
    required this.onTap,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? EosColors.plum : EosColors.slate300,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(selected ? 10 : 11),
                  child: InvitationCardRenderer(
                    template: template,
                    event: event,
                    compact: true,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.eosText.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(template.priceLabel, style: context.eosText.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.template, this.compact = false});

  final InvitationTemplate template;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = switch (template.tier) {
      InvitationTemplateTier.threeD => EosColors.info,
      InvitationTemplateTier.fourD => EosColors.plum,
      _ => EosColors.champagne,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        template.tier.badge,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
