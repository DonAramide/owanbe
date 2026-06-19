import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';

class AttendeeDashboardScreen extends ConsumerStatefulWidget {
  const AttendeeDashboardScreen({super.key});

  @override
  ConsumerState<AttendeeDashboardScreen> createState() => _AttendeeDashboardScreenState();
}

class _AttendeeDashboardScreenState extends ConsumerState<AttendeeDashboardScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(attendeeTicketsProvider);
    final session = ref.watch(authSessionProvider);

    return EosAppShell(
      brandLabel: 'Owanbe',
      brandSubtitle: 'My events',
      destinations: EosRoleDestinations.attendee,
      selectedIndex: _tab,
      onSelected: (i) {
        if (i == 0) context.go('/events');
        setState(() => _tab = i);
      },
      topBar: _AttendeeTopBar(
        name: session?.displayName ?? 'Guest',
        onSignOut: () {
          ref.read(authSessionProvider.notifier).signOut();
          context.go('/');
        },
      ),
      body: _tab == 1
          ? _TicketsTab(tickets: tickets)
          : _tab == 2
              ? _ScheduleTab(tickets: tickets)
              : _TicketsTab(tickets: tickets),
    );
  }
}

class _AttendeeTopBar extends StatelessWidget {
  const _AttendeeTopBar({required this.name, required this.onSignOut});
  final String name;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.eosColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant))),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg, vertical: context.eos.spacing.sm),
          child: Row(
            children: [
              Text('My tickets', style: context.eosText.titleLarge),
              const Spacer(),
              EosAttendeeChip(name: name, compact: true),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  const _TicketsTab({required this.tickets});
  final List<AttendeeTicket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.eos.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.confirmation_number_outlined, size: 48, color: context.eosColors.outline),
              SizedBox(height: context.eos.spacing.md),
              Text('No tickets yet', style: context.eosText.titleMedium),
              SizedBox(height: context.eos.spacing.sm),
              FilledButton(onPressed: () => context.go('/events'), child: const Text('Discover events')),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      itemCount: tickets.length,
      itemBuilder: (context, i) => Padding(
        padding: EdgeInsets.only(bottom: context.eos.spacing.md),
        child: _TicketCard(ticket: tickets[i]),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final AttendeeTicket ticket;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ticket.eventTitle, style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.xxs),
          Text('${ticket.tierName} · ${ticket.city}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.sm),
          EosCheckinStatus(checkedIn: ticket.checkedIn),
          SizedBox(height: context.eos.spacing.md),
          Center(
            child: Container(
              padding: EdgeInsets.all(context.eos.spacing.md),
              decoration: BoxDecoration(
                color: context.eosColors.surfaceContainerHighest,
                borderRadius: context.eos.radius.card,
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2, size: 120, color: context.eosColors.primary),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(ticket.qrPayload, style: context.eosText.labelSmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.tickets});
  final List<AttendeeTicket> tickets;

  @override
  Widget build(BuildContext context) {
    final sorted = [...tickets]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        for (final t in sorted)
          EosFeedItem(
            title: t.eventTitle,
            subtitle: '${t.venue} · ${t.tierName}',
            timestamp: _fmt(t.startsAt),
            leading: Icon(Icons.event, color: context.eosColors.primary),
          ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
