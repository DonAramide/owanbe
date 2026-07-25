import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../../identity/experience_navigation.dart';
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
      showSignIn: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.eos.spacing.xs),
              _HeroBanner(onBrowse: () => context.go('/events')),
              SizedBox(height: context.eos.spacing.xs),
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
              SizedBox(height: context.eos.spacing.sm),
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
      padding: EdgeInsets.all(context.eos.spacing.md),
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
        if (center)
          const OwambeLogo(size: 48)
        else
          const OwambeLogo(size: 40),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Discover events. Book with confidence.',
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: context.eosText.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Owambe connects you to premium celebrations with instant digital passes.',
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: context.eosText.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
        ),
        SizedBox(height: context.eos.spacing.sm),
        Wrap(
          spacing: context.eos.spacing.xs,
          runSpacing: context.eos.spacing.xs,
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          children: [
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                backgroundColor: EosColors.champagne,
                foregroundColor: EosColors.plumDark,
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 24 : 16,
                  vertical: context.eos.spacing.sm,
                ),
              ),
              child: const Text('Browse events'),
            ),
            OutlinedButton(
              onPressed: () => context.push('/attending'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 24 : 16,
                  vertical: context.eos.spacing.sm,
                ),
              ),
              child: const Text('I\'m attending an event'),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.xs),
        Row(
          mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            TextButton(
              onPressed: () => context.push(ExperienceNavigation.universalAuth()),
              child: Text(
                'Sign in',
                style: context.eosText.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const Text('|', style: TextStyle(color: Colors.white30)),
            TextButton(
              onPressed: () => context.push('/staff/login'),
              child: Text(
                'Staff login',
                style: context.eosText.labelSmall?.copyWith(color: Colors.white60),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
