import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/customer_guest_models.dart';
import '../providers/customer_guest_providers.dart';
import '../navigation/event_navigator.dart';
import '../workspace/event_empty_states.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/guests/add_guest_sheet.dart';
import '../widgets/guests/guest_detail_drawer.dart';
import '../widgets/guests/guest_filter_bar.dart';
import '../widgets/guests/guest_list_tile.dart';
import '../widgets/guests/import_contacts_sheet.dart';
import '../widgets/section_header.dart';
import '../widgets/summary_metric_card.dart';

/// Guest management at `/events/:eventId/guests`.
class CustomerEventGuestsScreen extends ConsumerStatefulWidget {
  const CustomerEventGuestsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventGuestsScreen> createState() => _CustomerEventGuestsScreenState();
}

class _CustomerEventGuestsScreenState extends ConsumerState<CustomerEventGuestsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openGuestDetail(CustomerGuestView guest) {
    ref.read(customerSelectedGuestProvider.notifier).state = guest;
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _showAddGuest() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddGuestSheet(eventId: widget.eventId),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest added to your list')),
      );
    }
  }

  Future<void> _showImportContacts() async {
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ImportContactsSheet(eventId: widget.eventId),
    );
    if (count != null && count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count contact(s)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final guestsAsync = ref.watch(customerEventGuestsProvider(widget.eventId));
    final filtered = ref.watch(customerFilteredGuestsProvider(widget.eventId));
    final selectedGuest = ref.watch(customerSelectedGuestProvider);

    return EventModuleScaffold(
      scaffoldKey: _scaffoldKey,
      eventId: widget.eventId,
      title: 'Guests',
      subtitle: 'Invitations, RSVPs, and check-in',
      endDrawer: selectedGuest == null
          ? null
          : GuestDetailDrawer(
              eventId: widget.eventId,
              guest: selectedGuest,
              onClose: () {
                ref.read(customerSelectedGuestProvider.notifier).state = null;
                _scaffoldKey.currentState?.closeEndDrawer();
              },
            ),
      actions: [
          IconButton(
            tooltip: 'Invitation hub',
            onPressed: () => context.eventNav.openInvitations(widget.eventId),
            icon: const Icon(Icons.mail_outline),
          ),
          IconButton(
            tooltip: 'Import contacts',
            onPressed: _showImportContacts,
            icon: const Icon(Icons.contacts_outlined),
          ),
          IconButton(
            tooltip: 'Add guest',
            onPressed: _showAddGuest,
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      body: guestsAsync.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'guests',
              onRetry: () => refreshCustomerGuests(ref),
              onBackToOverview: () => context.eventNav.backToOverview(widget.eventId),
            ),
          ],
        ),
        data: (allGuests) {
          final summary = summarizeGuests(allGuests);

          return EventModuleScrollBody(
            onRefresh: () async {
              refreshCustomerGuests(ref);
              await ref.read(customerEventGuestsProvider(widget.eventId).future);
            },
            primaryKpi: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    final cardWidth = wide
                        ? (constraints.maxWidth - 2 * context.eos.spacing.md) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: context.eos.spacing.md,
                      runSpacing: context.eos.spacing.md,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: SummaryMetricCard(
                            label: 'Invited',
                            value: '${summary.total}',
                            icon: Icons.groups_outlined,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: SummaryMetricCard(
                            label: 'RSVP',
                            value: '${summary.rsvpConfirmed}',
                            subtitle: 'Confirmed',
                            icon: Icons.mail_outline,
                            accentColor: EosColors.success,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: SummaryMetricCard(
                            label: 'Checked in',
                            value: '${summary.checkedIn}',
                            icon: Icons.how_to_reg_outlined,
                            accentColor: EosColors.plum,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search guests by name, email, or ticket',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => ref.read(customerGuestSearchProvider.notifier).state = v,
                ),
                SizedBox(height: context.eos.spacing.md),
                const GuestFilterBar(),
                SizedBox(height: context.eos.spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showAddGuest,
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Add guest'),
                      ),
                    ),
                    SizedBox(width: context.eos.spacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showImportContacts,
                        icon: const Icon(Icons.contacts_outlined),
                        label: const Text('Import'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.lg),
                filtered.when(
                  loading: () => const EventLoadingSkeleton(variant: EventLoadingVariant.list),
                  error: (_, _) => EventErrorView.module(
                    moduleLabel: 'guest list',
                    onRetry: () => ref.invalidate(customerFilteredGuestsProvider(widget.eventId)),
                    onBackToOverview: () => context.eventNav.backToOverview(widget.eventId),
                  ),
                  data: (guests) {
                    if (guests.isEmpty) {
                      return EventEmptyStates.guestsFiltered(onAdd: _showAddGuest);
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: guests.length,
                      itemBuilder: (context, index) {
                        final guest = guests[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: GuestListTile(
                            guest: guest,
                            onTap: () => _openGuestDetail(guest),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
