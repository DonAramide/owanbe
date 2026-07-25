import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
              Text(
                event.liveStatusLabel,
                style: context.eosText.labelMedium?.copyWith(
                  color: event.checkedIn ? Colors.green.shade800 : context.eosColors.onSurfaceVariant,
                ),
              ),
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

void showAttendeeQrSheet(
  BuildContext context,
  AttendeeEventView event, {
  Future<void> Function()? onResend,
  Future<void> Function()? onShare,
  Future<void> Function()? onDownload,
}) {
  final payload = event.qrPayload.trim();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(event.eventTitle, style: context.eosText.titleMedium),
          Text('${event.tierName} · ${event.lifecycleLabel} · ${event.city}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          Container(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: EosRadius.card,
              border: Border.all(color: context.eosColors.outlineVariant),
            ),
            child: Column(
              children: [
                if (payload.isEmpty)
                  Icon(Icons.qr_code_2, size: 160, color: context.eosColors.outline)
                else
                  QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                SizedBox(height: context.eos.spacing.sm),
                SelectableText(
                  payload.isEmpty ? 'Validation payload unavailable' : payload,
                  style: context.eosText.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (onShare != null)
                OutlinedButton.icon(
                  onPressed: () async => onShare(),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Share'),
                ),
              if (onDownload != null)
                OutlinedButton.icon(
                  onPressed: () async => onDownload(),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download'),
                ),
              if (onResend != null)
                OutlinedButton.icon(
                  onPressed: () async => onResend(),
                  icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                  label: const Text('Resend'),
                ),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    ),
  );
}
