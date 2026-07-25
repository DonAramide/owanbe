import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/customer_event_models.dart';

/// Event hero for the Event Desktop overview (Customer Event OS).
class EventDesktopHero extends StatelessWidget {
  const EventDesktopHero({
    super.key,
    required this.event,
    required this.daysUntil,
  });

  final CustomerEvent event;
  final int daysUntil;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.celebrantImageUrl;
    final venueLabel = event.venueName.isNotEmpty ? event.venueName : event.venue;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('data:')
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _gradientHero(event),
                  )
                : _gradientHero(event),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                ),
              ),
            ),
          ),
          Positioned(
            left: context.eos.spacing.lg,
            right: context.eos.spacing.lg,
            bottom: context.eos.spacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: context.eosText.headlineSmall?.copyWith(color: Colors.white)),
                if (event.tagline.isNotEmpty)
                  Text(
                    event.tagline,
                    style: context.eosText.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                SizedBox(height: context.eos.spacing.xs),
                Text(
                  '$venueLabel · ${event.city} · ${_formatDate(event.startsAt)}',
                  style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                ),
                if (daysUntil >= 0)
                  Text(
                    daysUntil == 0 ? 'Today' : '$daysUntil days to go',
                    style: context.eosText.labelMedium?.copyWith(
                      color: EosColors.champagne,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientHero(CustomerEvent event) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(event.coverGradientStart), Color(event.coverGradientEnd)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
