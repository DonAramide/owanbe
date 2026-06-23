import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/marketplace_models.dart';

class VendorReviewsList extends StatelessWidget {
  const VendorReviewsList({super.key, required this.reviews, required this.averageRating});

  final List<VendorReview> reviews;
  final double averageRating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              averageRating.toStringAsFixed(1),
              style: context.eosText.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(width: context.eos.spacing.xs),
            Icon(Icons.star_rounded, color: EosColors.champagne, size: 28),
            SizedBox(width: context.eos.spacing.sm),
            Text('${reviews.length} reviews', style: context.eosText.bodyMedium),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        for (final review in reviews)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: context.eosColors.primaryContainer,
                        child: Text(
                          review.authorName.isNotEmpty ? review.authorName[0] : '?',
                          style: context.eosText.labelSmall?.copyWith(color: context.eosColors.primary),
                        ),
                      ),
                      SizedBox(width: context.eos.spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(review.authorName, style: context.eosText.titleSmall),
                            Text(review.eventType, style: context.eosText.labelSmall),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: EosColors.champagne),
                          Text(review.rating.toStringAsFixed(1), style: context.eosText.labelSmall),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  Text(review.comment, style: context.eosText.bodyMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
