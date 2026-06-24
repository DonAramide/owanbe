import 'package:flutter/material.dart';

import '../../../eos/eos.dart';
import '../models/attendee_event_models.dart';

/// Rich event card for attendees — mirrors organizer event cards with full details.
class AttendeeEventCard extends StatelessWidget {
  const AttendeeEventCard({
    super.key,
    required this.event,
    this.onOpenDetail,
    this.onShowQr,
  });

  final AttendeeEventView event;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onShowQr;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      onTap: onOpenDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: EosRadius.input,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(event.coverGradientStart), Color(event.coverGradientEnd)],
                ),
              ),
              padding: EdgeInsets.all(context.eos.spacing.md),
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (event.category.isNotEmpty)
                    Text(
                      event.category.toUpperCase(),
                      style: context.eosText.labelSmall?.copyWith(color: Colors.white70),
                    ),
                  Text(
                    event.eventTitle,
                    style: context.eosText.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (event.tagline.isNotEmpty)
                    Text(
                      event.tagline,
                      style: context.eosText.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined, size: 18, color: context.eosColors.primary),
              SizedBox(width: context.eos.spacing.xs),
              Expanded(child: Text(event.tierName, style: context.eosText.titleSmall)),
              EosCheckinStatus(checkedIn: event.checkedIn),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          _DetailRow(icon: Icons.schedule, label: formatAttendeeDateRange(event.startsAt, event.endsAt)),
          SizedBox(height: context.eos.spacing.xs),
          _DetailRow(icon: Icons.place_outlined, label: '${event.venue}, ${event.city}'),
          if (event.attendeeCount != null) ...[
            SizedBox(height: context.eos.spacing.xs),
            _DetailRow(icon: Icons.people_outline, label: '${event.attendeeCount}+ attending'),
          ],
          SizedBox(height: context.eos.spacing.sm),
          Text(
            event.description,
            style: context.eosText.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: context.eos.spacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowQr,
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('My QR ticket'),
                ),
              ),
              if (onOpenDetail != null) ...[
                SizedBox(width: context.eos.spacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenDetail,
                    child: const Text('Full details'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.eosColors.onSurfaceVariant),
        SizedBox(width: context.eos.spacing.xs),
        Expanded(child: Text(label, style: context.eosText.bodySmall)),
      ],
    );
  }
}

void showAttendeeQrSheet(BuildContext context, AttendeeEventView event) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(event.eventTitle, style: context.eosText.titleMedium),
          Text('${event.tierName} · ${event.city}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          Container(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            decoration: BoxDecoration(
              color: context.eosColors.surfaceContainerHighest,
              borderRadius: EosRadius.card,
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code_2, size: 160, color: context.eosColors.primary),
                SizedBox(height: context.eos.spacing.sm),
                SelectableText(event.qrPayload, style: context.eosText.labelSmall),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    ),
  );
}
