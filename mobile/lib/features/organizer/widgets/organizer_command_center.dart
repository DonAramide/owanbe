import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../portals/customer/closing/event_closing_actions.dart';
import '../../../portals/customer/portfolio/event_template_catalog.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import 'organizer_shared.dart';
import '../../../shared/models/event_access_mode.dart';

/// Bottom sheet to start create flow from a named template (wizard seed).
Future<void> showOrganizerTemplatePicker(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.eos.spacing.lg,
            0,
            context.eos.spacing.lg,
            context.eos.spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Event templates', style: context.eosText.titleMedium),
              SizedBox(height: context.eos.spacing.xs),
              Text(
                'Pre-fill the event wizard with budgets, services, and ticket tiers.',
                style: context.eosText.bodySmall,
              ),
              SizedBox(height: context.eos.spacing.md),
              for (final kind in portfolioEventTemplates)
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(kind.label),
                  subtitle: Text(templateDefinition(kind).description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    seedDuplicateEvent(ref, buildTemplateDraft(kind));
                    Navigator.of(ctx).pop();
                    context.push('/organizer/events/new');
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom sheet to pick an event and duplicate into Wizard V2.
Future<void> showOrganizerDuplicatePicker(BuildContext context, WidgetRef ref) async {
  final events = await ref.read(organizerEventsProvider.future);
  if (!context.mounted) return;
  if (events.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create an event first, then you can duplicate it.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.eos.spacing.lg,
            0,
            context.eos.spacing.lg,
            context.eos.spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Duplicate event', style: context.eosText.titleMedium),
              SizedBox(height: context.eos.spacing.xs),
              Text(
                'Choose an event to copy into the create wizard.',
                style: context.eosText.bodySmall,
              ),
              SizedBox(height: context.eos.spacing.md),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final e = events[index];
                    return ListTile(
                      leading: const Icon(Icons.copy_outlined),
                      title: Text(e.title),
                      subtitle: Text('${organizerStatusLabel(e.status)} · ${e.city}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        duplicateOrganizerEvent(ref, e);
                        Navigator.of(ctx).pop();
                        context.push('/organizer/events/new');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

EventWizardV2Draft buildDuplicateDraftFromOrganizerEvent(OrganizerEvent event) {
  final nextYear = DateTime(
    event.startsAt.year + 1,
    event.startsAt.month,
    event.startsAt.day,
    event.startsAt.hour,
    event.startsAt.minute,
  );
  final duration = event.endsAt.difference(event.startsAt);

  return EventWizardV2Draft(
    categorySlug: event.categorySlug.isNotEmpty ? event.categorySlug : event.category.toLowerCase(),
    categoryLabel: event.category,
    title: '${event.title} (Copy)',
    tagline: event.tagline,
    description: event.description,
    city: event.city,
    venueName: event.venueName.isNotEmpty ? event.venueName : event.venue,
    venueAddress: event.venueAddress.isNotEmpty ? event.venueAddress : event.venue,
    budgetMinor: event.budgetMinor,
    expectedGuests: event.expectedGuests,
    tags: event.tags,
    startsAt: nextYear,
    endsAt: nextYear.add(duration.isNegative ? const Duration(hours: 6) : duration),
    ticketTiers: [
      for (final tier in event.ticketTiers)
        OrganizerTicketTier(
          id: 'tier_${DateTime.now().millisecondsSinceEpoch}_${tier.id}',
          name: tier.name,
          description: tier.description,
          priceMinor: tier.priceMinor,
          currency: tier.currency,
          capacity: tier.capacity,
          remaining: tier.capacity,
          tierType: tier.tierType,
          visibility: tier.visibility,
        ),
    ],
    eventAccessMode: event.eventAccessMode,
    listingVisibility: event.listingVisibility.isNotEmpty
        ? event.listingVisibility
        : (event.eventAccessMode == EventAccessMode.publicTicketed ? 'public' : 'invite_only'),
    celebrantImageUrl: event.celebrantImageUrl,
    venueType: event.venueType,
    requiredServices: event.requiredServices,
    language: event.language,
    ageRestrictionMin: event.ageRestrictionMin,
    registrationEnabled: event.registrationEnabled,
    checkInEnabled: event.checkInEnabled,
    themeColor: event.themeColor,
    venueDeferred: event.venueDeferred,
    state: event.state,
    lga: event.lga,
    selectedTemplateSlug: event.selectedTemplateSlug,
    venueLatitude: event.venueLatitude,
    venueLongitude: event.venueLongitude,
    googlePlaceId: event.googlePlaceId,
    bannerLabel: event.bannerLabel,
  );
}

void duplicateOrganizerEvent(WidgetRef ref, OrganizerEvent event) {
  seedDuplicateEvent(ref, buildDuplicateDraftFromOrganizerEvent(event));
}
