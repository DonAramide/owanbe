import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/models/customer_event_models.dart';
import 'package:owambe/portals/customer/portfolio/event_template_catalog.dart';
import 'package:owambe/portals/customer/portfolio/organizer_portfolio_models.dart';
import 'package:owambe/shared/models/event_access_mode.dart';

CustomerEvent _event({
  required String id,
  CustomerEventStatus status = CustomerEventStatus.published,
  String category = 'Wedding',
  DateTime? startsAt,
}) =>
    CustomerEvent(
      id: id,
      title: 'Event $id',
      tagline: '',
      description: '',
      city: 'Lagos',
      venue: 'Hall',
      startsAt: startsAt ?? DateTime.now().add(const Duration(days: 30)),
      endsAt: (startsAt ?? DateTime.now().add(const Duration(days: 30))).add(const Duration(hours: 6)),
      category: category,
      status: status,
      coverGradientStart: 0,
      coverGradientEnd: 0,
      ticketTiers: const [
        CustomerTicketTier(
          id: 't1',
          name: 'Regular',
          description: '',
          priceMinor: 1500000,
          currency: 'NGN',
          capacity: 100,
          remaining: 10,
        ),
      ],
      vendors: const [
        CustomerVendorSlot(
          id: 'v1',
          businessName: 'Elite Catering',
          category: 'Catering',
          tier: 'gold',
          status: CustomerVendorSlotStatus.approved,
          ordersCount: 2,
          revenueMinor: 500000,
        ),
      ],
      attendees: const [
        CustomerAttendee(
          id: 'a1',
          name: 'Ada',
          email: 'ada@example.com',
          tierName: 'VIP',
          ticketId: 'tk1',
          checkedIn: true,
        ),
      ],
      expectedGuests: 100,
      budgetMinor: 10000000,
      eventAccessMode: EventAccessMode.publicTicketed,
    );

void main() {
  test('portfolio KPIs aggregate from customer events without duplicate logic', () {
    final events = [
      _event(id: 'e1', status: CustomerEventStatus.completed),
      _event(id: 'e2', status: CustomerEventStatus.published),
      _event(id: 'e3', status: CustomerEventStatus.cancelled),
    ];

    final kpis = buildPortfolioKpiSnapshot(events);
    expect(kpis.totalEvents, 3);
    expect(kpis.activeEvents, 1);
    expect(kpis.completedEvents, 1);
    expect(kpis.cancelledEvents, 1);
    expect(kpis.ticketsSold, greaterThan(0));
    expect(kpis.vendorRequests, 3);
  });

  test('copilot generates proactive portfolio insights', () {
    final events = [
      _event(id: 'w1', status: CustomerEventStatus.completed, category: 'Wedding'),
      _event(id: 'w2', status: CustomerEventStatus.published, category: 'Wedding'),
    ];

    final insights = buildPortfolioCopilotInsights(events);
    expect(insights, isNotEmpty);
    expect(insights.any((i) => i.category.contains('Guest') || i.category.contains('Proactive')), isTrue);
  });

  test('vendor intelligence ranks across events', () {
    final events = [_event(id: 'e1'), _event(id: 'e2')];
    final ranks = buildPortfolioVendorRankings(events);
    expect(ranks, isNotEmpty);
    expect(ranks.first.businessName, 'Elite Catering');
  });

  test('automation detects planning risks on upcoming events', () {
    final events = [
      _event(
        id: 'risk',
        status: CustomerEventStatus.draft,
        startsAt: DateTime.now().add(const Duration(days: 10)),
      ),
    ];
    final alerts = buildPortfolioAutomationAlerts(events);
    expect(alerts.any((a) => a.kind == 'planning_risk'), isTrue);
  });

  test('event templates produce wizard drafts', () {
    final draft = buildTemplateDraft(EventTemplateKind.wedding);
    expect(draft.title, contains('Wedding'));
    expect(draft.requiredServices, isNotEmpty);
    expect(draft.budgetMinor, greaterThan(0));
  });

  test('portfolio workspace bundles all intelligence layers', () {
    final workspace = buildOrganizerPortfolioWorkspace([
      _event(id: 'e1', status: CustomerEventStatus.completed),
      _event(id: 'e2'),
    ]);

    expect(workspace.kpis.totalEvents, 2);
    expect(workspace.analytics.eventComparisons, isNotEmpty);
    expect(workspace.executive.portfolioHealth, greaterThan(0));
    expect(workspace.weeklyBriefing, isNotEmpty);
  });
}
