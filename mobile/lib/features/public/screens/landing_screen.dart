import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/public_providers.dart';
import '../widgets/public_event_grid.dart';
import '../widgets/public_shell_mixin.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(publicEventsProvider);

    return buildPublicShell(
      context: context,
      ref: ref,
      activeNav: 'home',
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.eos.spacing.xl),
              _HeroBanner(onBrowse: () => context.go('/events')),
              SizedBox(height: context.eos.spacing.xxl),
              EosSection(
                title: 'Featured events',
                subtitle: 'Curated experiences across West Africa',
                trailing: TextButton(onPressed: () => context.go('/events'), child: const Text('View all')),
                child: featured.when(
                  data: (events) => PublicEventGrid(
                    events: events.where((e) => e.isFeatured).take(2).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                ),
              ),
              _ValueProps(),
              SizedBox(height: context.eos.spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.eos.spacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EosColors.plumDark, EosColors.plum, EosColors.plumLight],
        ),
        borderRadius: EosRadius.card,
        boxShadow: context.eos.shadowElevated,
      ),
      child: EosResponsive(
        mobile: _heroContent(context, onBrowse, center: true),
        tablet: _heroContent(context, onBrowse),
        desktop: _heroContent(context, onBrowse, wide: true),
      ),
    );
  }

  Widget _heroContent(BuildContext context, VoidCallback onBrowse, {bool center = false, bool wide = false}) {
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'Discover events.\nBook with confidence.',
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: context.eosText.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text(
          'Owanbe connects you to premium celebrations — with secure ticketing and instant digital passes.',
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: context.eosText.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
        ),
        SizedBox(height: context.eos.spacing.lg),
        Wrap(
          spacing: context.eos.spacing.sm,
          runSpacing: context.eos.spacing.sm,
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          children: [
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                backgroundColor: EosColors.champagne,
                foregroundColor: EosColors.plumDark,
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 32 : 24,
                  vertical: context.eos.spacing.md,
                ),
              ),
              child: const Text('Browse events'),
            ),
            TextButton(
              onPressed: () => context.push('/staff/login'),
              child: Text(
                'Staff login',
                style: context.eosText.labelSmall?.copyWith(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/staff/login?role=organizer'),
              child: Text(
                'Organizer portal',
                style: context.eosText.labelSmall?.copyWith(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/staff/login?role=vendor'),
              child: Text(
                'Vendor portal',
                style: context.eosText.labelSmall?.copyWith(color: Colors.white60),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ValueProps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.confirmation_number_outlined, 'Instant tickets', 'Digital passes delivered immediately after payment'),
      (Icons.verified_user_outlined, 'Secure checkout', 'Protected payments with clear receipts'),
      (Icons.qr_code_2, 'Easy entry', 'Show your QR code at the door'),
    ];
    return Wrap(
      spacing: context.eos.spacing.md,
      runSpacing: context.eos.spacing.md,
      children: items.map((item) {
        return SizedBox(
          width: 280,
          child: EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$1, color: context.eosColors.primary, size: 28),
                SizedBox(height: context.eos.spacing.sm),
                Text(item.$2, style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xxs),
                Text(item.$3, style: context.eosText.bodySmall),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
