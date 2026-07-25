import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/widgets/attendee_event_card.dart';
import '../../../features/workspace/widgets/workspace_experience_shell.dart';
import '../../../identity/workspace_models.dart';
import '../navigation/attendee_routes.dart';
import '../widgets/attendee_top_bar.dart';

/// Search and recover tickets already linked to the signed-in guest account.
class AttendeeFindTicketScreen extends ConsumerStatefulWidget {
  const AttendeeFindTicketScreen({super.key});

  @override
  ConsumerState<AttendeeFindTicketScreen> createState() => _AttendeeFindTicketScreenState();
}

class _AttendeeFindTicketScreenState extends ConsumerState<AttendeeFindTicketScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(attendeeEventsProvider);
    final query = _query.text.trim().toLowerCase();

    return WorkspaceExperienceShell(
      workspace: ExperienceWorkspace.attendee,
      child: Column(
        children: [
          const AttendeeTopBar(),
          Expanded(
            child: RefreshIndicator(
                onRefresh: () => ref.refresh(attendeeEventsProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/attendee'),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back to tickets'),
                      ),
                    ),
                    Text('Find my ticket', style: context.eosText.headlineMedium),
                    SizedBox(height: context.eos.spacing.xs),
                    Text(
                      'Search tickets linked to your account by event name, city, or venue.',
                      style: context.eosText.bodyMedium,
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    EosSearchField(
                      hint: 'Search your tickets…',
                      onChanged: (_) => setState(() {}),
                      controller: _query,
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    eventsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => EosSurfaceCard(child: Text('$e')),
                      data: (events) {
                        final filtered = query.isEmpty
                            ? events
                            : events
                                .where(
                                  (e) =>
                                      e.eventTitle.toLowerCase().contains(query) ||
                                      e.city.toLowerCase().contains(query) ||
                                      e.venue.toLowerCase().contains(query) ||
                                      e.tierName.toLowerCase().contains(query),
                                )
                                .toList();

                        if (filtered.isEmpty) {
                          return EosSurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  query.isEmpty ? 'No tickets linked yet' : 'No tickets match your search',
                                  style: context.eosText.titleMedium,
                                ),
                                SizedBox(height: context.eos.spacing.sm),
                                Text(
                                  query.isEmpty
                                      ? 'Buy a ticket from Discover or check your email for a transfer link.'
                                      : 'Try a different search term or browse Discover for new events.',
                                  style: context.eosText.bodyMedium,
                                ),
                                SizedBox(height: context.eos.spacing.md),
                                FilledButton(
                                  onPressed: () => context.go('/attendee'),
                                  child: const Text('Back to tickets'),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final event in filtered) ...[
                              AttendeeEventCard(
                                event: event,
                                onOpenDetail: () => context.push(AttendeeRoutes.eventDetail(event.eventId)),
                                onShowQr: () => showAttendeeQrSheet(context, event),
                              ),
                              SizedBox(height: context.eos.spacing.md),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
