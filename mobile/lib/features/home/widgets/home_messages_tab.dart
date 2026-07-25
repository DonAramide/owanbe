import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../../eos/eos.dart';

import '../../../identity/experience_navigation.dart';

import '../../../identity/identity_provider.dart';

import '../../../identity/workspace_models.dart';

import '../../../portals/customer/widgets/section_header.dart';

import '../providers/living_home_providers.dart';

import 'home_section_async.dart';



/// Messages preview tab — loads independently from home feed.

class HomeMessagesTab extends ConsumerWidget {

  const HomeMessagesTab({super.key});



  String _relative(DateTime t) {

    final d = DateTime.now().difference(t);

    if (d.inMinutes < 60) return '${d.inMinutes}m ago';

    if (d.inHours < 24) return '${d.inHours}h ago';

    return '${d.inDays}d ago';

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final messagesAsync = ref.watch(homeMessagePreviewsProvider);

    final identity = ref.watch(userIdentityProvider).valueOrNull;

    final pad = context.eos.spacing.lg;



    return messagesAsync.when(

      loading: () => ListView(

        padding: EdgeInsets.all(pad),

        children: const [

          SectionHeader(title: 'Messages', subtitle: 'Updates across your workspaces'),

          HomeSectionLoading(title: 'Loading messages…'),

        ],

      ),

      error: (e, _) => ListView(

        padding: EdgeInsets.all(pad),

        children: [

          const SectionHeader(title: 'Messages', subtitle: 'Updates across your workspaces'),

          HomeSectionError(

            title: 'Messages unavailable',

            message: '$e',

            onRetry: () => ref.invalidate(homeMessagePreviewsProvider),

          ),

        ],

      ),

      data: (messages) => RefreshIndicator(

        onRefresh: () async => refreshLivingHome(ref),

        child: ListView(

          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 88),

          children: [

            const SectionHeader(

              title: 'Messages',

              subtitle: 'Updates across your workspaces',

            ),

            if (messages.isEmpty)

              EosSurfaceCard(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    Text('No messages yet', style: context.eosText.titleSmall),

                    SizedBox(height: context.eos.spacing.xs),

                    Text(

                      'Invitations, booking requests, and team updates will appear here.',

                      style: context.eosText.bodySmall,

                    ),

                  ],

                ),

              )

            else

              ...messages.map(

                (m) => Padding(

                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),

                  child: EosFeedItem(

                    title: m.sender,

                    subtitle: m.preview,

                    timestamp: _relative(m.sentAt),

                    leading: CircleAvatar(

                      radius: 18,

                      backgroundColor: m.unread

                          ? EosColors.champagne.withValues(alpha: 0.25)

                          : Colors.white12,

                      child: Icon(

                        Icons.chat_bubble_outline,

                        size: 18,

                        color: m.unread ? EosColors.champagne : Colors.white54,

                      ),

                    ),

                    onTap: () {

                      if (identity == null) return;

                      if (identity.canAccess(ExperienceWorkspace.vendor) &&

                          m.sender.contains('Booking')) {

                        context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.vendor));

                      } else if (identity.canAccess(ExperienceWorkspace.organizer)) {

                        context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.organizer));

                      } else {

                        context.go('/events');

                      }

                    },

                  ),

                ),

              ),

          ],

        ),

      ),

    );

  }

}


