import '../../../features/organizer/models/organizer_models.dart';
import '../../../shared/models/event_access_mode.dart';
import '../models/ai_planner_models.dart';

/// Named event templates — elevate duplicate flow without a new wizard.
enum EventTemplateKind {
  wedding,
  birthday,
  conference,
  church,
  corporate,
  family,
}

extension EventTemplateKindX on EventTemplateKind {
  String get label => switch (this) {
        EventTemplateKind.wedding => 'Wedding',
        EventTemplateKind.birthday => 'Birthday',
        EventTemplateKind.conference => 'Conference',
        EventTemplateKind.church => 'Church Event',
        EventTemplateKind.corporate => 'Corporate Event',
        EventTemplateKind.family => 'Family Event',
      };

  String get categorySlug => switch (this) {
        EventTemplateKind.wedding => 'wedding',
        EventTemplateKind.birthday => 'birthday',
        EventTemplateKind.conference => 'conference',
        EventTemplateKind.church => 'church',
        EventTemplateKind.corporate => 'corporate',
        EventTemplateKind.family => 'family',
      };

  AiPlannerEventType get plannerType => switch (this) {
        EventTemplateKind.wedding => AiPlannerEventType.wedding,
        EventTemplateKind.birthday => AiPlannerEventType.birthday,
        EventTemplateKind.conference => AiPlannerEventType.corporate,
        EventTemplateKind.church => AiPlannerEventType.festival,
        EventTemplateKind.corporate => AiPlannerEventType.corporate,
        EventTemplateKind.family => AiPlannerEventType.anniversary,
      };
}

class EventTemplateDefinition {
  const EventTemplateDefinition({
    required this.kind,
    required this.description,
    required this.requiredServices,
    required this.budgetMinor,
    required this.expectedGuests,
    required this.ticketTiers,
    required this.tags,
    required this.eventAccessMode,
  });

  final EventTemplateKind kind;
  final String description;
  final List<String> requiredServices;
  final int budgetMinor;
  final int expectedGuests;
  final List<OrganizerTicketTier> ticketTiers;
  final List<String> tags;
  final EventAccessMode eventAccessMode;
}

List<String> _servicesFor(EventTemplateKind kind) => switch (kind) {
      EventTemplateKind.wedding => ['Venue', 'Catering', 'Photography', 'DJ', 'Decoration', 'Security'],
      EventTemplateKind.birthday => ['Venue', 'Catering', 'DJ', 'Photography', 'Decoration'],
      EventTemplateKind.conference => ['Venue', 'Catering', 'AV Equipment', 'Security', 'Photography'],
      EventTemplateKind.church => ['Venue', 'Catering', 'Decoration', 'Photography', 'Ushering'],
      EventTemplateKind.corporate => ['Venue', 'Catering', 'AV Equipment', 'Security', 'Branding'],
      EventTemplateKind.family => ['Venue', 'Catering', 'Photography', 'Decoration', 'Entertainment'],
    };

EventTemplateDefinition templateDefinition(EventTemplateKind kind) {
  final guests = switch (kind) {
    EventTemplateKind.wedding => 250,
    EventTemplateKind.birthday => 150,
    EventTemplateKind.conference => 300,
    EventTemplateKind.church => 400,
    EventTemplateKind.corporate => 200,
    EventTemplateKind.family => 100,
  };

  final budget = switch (kind) {
    EventTemplateKind.wedding => 800000000,
    EventTemplateKind.birthday => 350000000,
    EventTemplateKind.conference => 1200000000,
    EventTemplateKind.church => 450000000,
    EventTemplateKind.corporate => 900000000,
    EventTemplateKind.family => 250000000,
  };

  final access = switch (kind) {
    EventTemplateKind.conference || EventTemplateKind.corporate => EventAccessMode.publicTicketed,
    _ => EventAccessMode.privateInvitation,
  };

  final tiers = access == EventAccessMode.publicTicketed
      ? [
          OrganizerTicketTier(
            id: 'regular',
            name: 'Regular',
            description: 'Standard admission',
            priceMinor: 1500000,
            currency: 'NGN',
            capacity: guests,
            remaining: guests,
          ),
          OrganizerTicketTier(
            id: 'vip',
            name: 'VIP',
            description: 'Premium access',
            priceMinor: 3500000,
            currency: 'NGN',
            capacity: (guests * 0.2).round(),
            remaining: (guests * 0.2).round(),
            tierType: TicketTierType.vip,
          ),
        ]
      : <OrganizerTicketTier>[];

  return EventTemplateDefinition(
    kind: kind,
    description: '${kind.label} template with checklist, budget, and vendor preferences.',
    requiredServices: _servicesFor(kind),
    budgetMinor: budget,
    expectedGuests: guests,
    ticketTiers: tiers,
    tags: [kind.label, 'Template'],
    eventAccessMode: access,
  );
}

/// Builds a wizard draft from a named template — reuses Event Wizard V2.
EventWizardV2Draft buildTemplateDraft(EventTemplateKind kind) {
  final def = templateDefinition(kind);
  final starts = DateTime.now().add(const Duration(days: 90));

  return EventWizardV2Draft(
    categorySlug: kind.categorySlug,
    categoryLabel: kind.label,
    eventAccessMode: def.eventAccessMode,
    listingVisibility: def.eventAccessMode == EventAccessMode.publicTicketed ? 'public' : 'invite_only',
    title: '${kind.label} ${starts.year}',
    tagline: def.description,
    description: def.description,
    city: 'Lagos',
    expectedGuests: def.expectedGuests,
    budgetMinor: def.budgetMinor,
    tags: def.tags,
    startsAt: starts,
    endsAt: starts.add(const Duration(hours: 8)),
    ticketTiers: def.ticketTiers,
    requiredServices: def.requiredServices,
    venueDeferred: false,
    state: 'Lagos',
    lga: 'Eti-Osa',
    selectedTemplateSlug: kind.categorySlug,
  );
}

/// AI planning baseline inputs for a template.
AiPlannerInputs templatePlannerBaseline(EventTemplateKind kind) {
  final def = templateDefinition(kind);
  return AiPlannerInputs(
    eventType: kind.plannerType,
    budgetMinor: def.budgetMinor,
    guestCount: def.expectedGuests,
    location: 'Lagos',
  );
}

const portfolioEventTemplates = EventTemplateKind.values;
