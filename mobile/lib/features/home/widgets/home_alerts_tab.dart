import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../../eos/eos.dart';

import '../../../identity/experience_navigation.dart';

import '../../../identity/workspace_models.dart';

import '../../../portals/customer/widgets/section_header.dart';

import '../providers/living_home_providers.dart';

import 'home_section_async.dart';



/// Alerts and notifications tab — each source loads independently.

class HomeAlertsTab extends ConsumerWidget {

  const HomeAlertsTab({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final organizerAlertsAsync = ref.watch(hubOrganizerAlertsProvider);

    final vendorStatsAsync = ref.watch(hubVendorDashboardProvider);

    final pad = context.eos.spacing.lg;



    final organizerAlerts = organizerAlertsAsync.valueOrNull ?? const [];

    final vendorStats = vendorStatsAsync.valueOrNull;

    final hasUserAlerts = organizerAlerts.isNotEmpty ||

        (vendorStats != null && vendorStats.totalBookings > 0);



    final isLoading = organizerAlertsAsync.isLoading || vendorStatsAsync.isLoading;

    final hasError = organizerAlertsAsync.hasError && vendorStatsAsync.hasError;



    return RefreshIndicator(

      onRefresh: () async => refreshLivingHome(ref),

      child: ListView(

        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 88),

        children: [

          const SectionHeader(

            title: 'Alerts',

            subtitle: 'Tasks and notifications requiring action',

          ),

          if (isLoading && !hasUserAlerts)

            const HomeSectionLoading(title: 'Loading alerts…')

          else if (hasError && !hasUserAlerts)

            HomeSectionError(

              title: 'Alerts unavailable',

              message: '${organizerAlertsAsync.error ?? vendorStatsAsync.error}',

              onRetry: () {

                ref.invalidate(hubOrganizerAlertsProvider);

                ref.invalidate(hubVendorDashboardProvider);

              },

            )

          else if (!hasUserAlerts)

            EosSurfaceCard(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  Text('All caught up', style: context.eosText.titleSmall),

                  SizedBox(height: context.eos.spacing.xs),

                  Text(

                    'No pending approvals or platform alerts right now.',

                    style: context.eosText.bodySmall,

                  ),

                ],

              ),

            ),

          for (final item in organizerAlerts)

            Padding(

              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),

              child: EosAttentionBanner(

                headline: item.headline,

                message: item.message,

                severity: item.severity,

                actionLabel: 'Open organizer',

                onAction: () => context.go(

                  ExperienceNavigation.workspaceHome(ExperienceWorkspace.organizer),

                ),

              ),

            ),

          if (vendorStats != null && vendorStats.totalBookings > 0)

            Padding(

              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),

              child: EosAttentionBanner(

                headline: 'Booking requests',

                message: '${vendorStats.totalBookings} bookings need your attention.',

                severity: 'WARNING',

                actionLabel: 'View vendor',

                onAction: () => context.go(

                  ExperienceNavigation.workspaceHome(ExperienceWorkspace.vendor),

                ),

              ),

            ),

          for (final a in livingHomeAnnouncements)

            Padding(

              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),

              child: EosAttentionBanner(

                headline: a.title,

                message: a.body,

                severity: a.severity,

              ),

            ),

        ],

      ),

    );

  }

}


