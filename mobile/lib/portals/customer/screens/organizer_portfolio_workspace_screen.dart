import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../identity/experience_navigation.dart';
import '../../../navigation/enterprise_back_handler.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../closing/event_closing_actions.dart';
import '../navigation/event_navigator.dart';
import '../portfolio/event_template_catalog.dart';
import '../portfolio/organizer_portfolio_models.dart';
import '../portfolio/organizer_portfolio_provider.dart';

/// Organizer Portfolio Workspace — enterprise intelligence across all events (Phase 6).
class OrganizerPortfolioWorkspaceScreen extends ConsumerWidget {
  const OrganizerPortfolioWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(organizerPortfolioWorkspaceProvider);

    return WorkspaceBackScope(
      child: Scaffold(
        backgroundColor: context.eosCanvas,
        appBar: AppBar(
        backgroundColor: context.eosCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          tooltip: 'Back',
          onPressed: () => ExperienceNavigation.navigateBack(context),
        ),
        title: const Text('Portfolio Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => refreshOrganizerPortfolio(ref),
          ),
        ],
      ),
      body: portfolio.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Portfolio unavailable: $e')),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            refreshOrganizerPortfolio(ref);
            await ref.read(organizerPortfolioWorkspaceProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              Text(
                'Organizer Portfolio',
                style: context.eosText.headlineSmall,
              ),
              SizedBox(height: context.eos.spacing.xs),
              Text(
                'Intelligence across your entire event portfolio — not a replacement for Home.',
                style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
              ),
              SizedBox(height: context.eos.spacing.lg),
              _ExecutiveStrip(executive: data.executive),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Portfolio overview'),
              _KpiGrid(kpis: data.kpis),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Upcoming events'),
              _UpcomingList(events: data.upcomingEvents),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Portfolio timeline'),
              _TimelineList(entries: data.timeline),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Portfolio analytics'),
              _AnalyticsPanel(analytics: data.analytics),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('AI Organizer Copilot'),
              _CopilotPanel(insights: data.copilotInsights),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Vendor intelligence'),
              _VendorPanel(rankings: data.vendorRankings),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Guest intelligence'),
              _GuestPanel(insights: data.guestInsights),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Financial intelligence'),
              _FinancialPanel(financial: data.financial),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Event templates'),
              _TemplatePanel(),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('AI automation'),
              _AutomationPanel(alerts: data.automationAlerts),
              SizedBox(height: context.eos.spacing.lg),
              _SectionTitle('Weekly briefing'),
              _BriefingPanel(lines: data.weeklyBriefing),
              SizedBox(height: context.eos.spacing.xl),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Text(label, style: context.eosText.titleMedium),
    );
  }
}

class _ExecutiveStrip extends StatelessWidget {
  const _ExecutiveStrip({required this.executive});
  final ExecutiveDashboardSnapshot executive;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Executive dashboard', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.sm,
            runSpacing: context.eos.spacing.sm,
            children: [
              EosKpiCard(
                title: 'Portfolio health',
                value: '${executive.portfolioHealth}',
                subtitle: 'Success index',
              ),
              EosKpiCard(
                title: 'Monthly revenue',
                value: formatRevenue(executive.monthlyRevenueMinor),
                subtitle: 'Latest month',
              ),
              EosKpiCard(
                title: 'Vendor network',
                value: '${executive.vendorNetworkSize}',
                subtitle: 'Unique vendors',
              ),
              EosKpiCard(
                title: 'Operational risk',
                value: executive.operationalRiskLevel,
                subtitle: 'Automation scan',
              ),
            ],
          ),
          if (executive.aiRecommendations.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.md),
            Text('AI recommendations', style: context.eosText.labelLarge),
            for (final rec in executive.aiRecommendations)
              Padding(
                padding: EdgeInsets.only(top: context.eos.spacing.xs),
                child: Text('• $rec', style: context.eosText.bodySmall),
              ),
          ],
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});
  final PortfolioKpiSnapshot kpis;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total events', '${kpis.totalEvents}'),
      ('Active', '${kpis.activeEvents}'),
      ('Completed', '${kpis.completedEvents}'),
      ('Cancelled', '${kpis.cancelledEvents}'),
      ('Revenue', formatRevenue(kpis.revenueMinor)),
      ('Profit', formatRevenue(kpis.profitMinor)),
      ('Guests', '${kpis.guestsInvited}'),
      ('Tickets sold', '${kpis.ticketsSold}'),
      ('Vendor requests', '${kpis.vendorRequests}'),
      ('Vendor spend', formatRevenue(kpis.vendorSpendMinor)),
      ('Outstanding', formatRevenue(kpis.outstandingMinor)),
      ('Avg success', '${kpis.averageSuccessScore}%'),
    ];

    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        for (final (title, value) in items)
          SizedBox(
            width: 160,
            child: EosKpiCard(title: title, value: value, subtitle: ''),
          ),
      ],
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.events});
  final List<PortfolioEventRow> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text('No upcoming events', style: context.eosText.bodyMedium);
    }
    return Column(
      children: [
        for (final event in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(event.title),
            subtitle: Text('${event.category} · ${event.status.name}'),
            trailing: Text(event.daysUntilLabel),
            onTap: () => context.eventNav.openOverview(event.eventId),
          ),
      ],
    );
  }
}

extension on PortfolioEventRow {
  String get daysUntilLabel {
    final now = DateTime.now();
    final days = startsAt.difference(now).inDays;
    if (days < 0) return 'Past';
    if (days == 0) return 'Today';
    return 'In $days days';
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.entries});
  final List<PortfolioTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Text('No timeline entries', style: context.eosText.bodyMedium);
    return Column(
      children: [
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              entry.daysUntil == 0 ? Icons.circle : Icons.circle_outlined,
              size: 12,
              color: EosColors.champagne,
            ),
            title: Text(entry.title),
            subtitle: Text('${entry.status.name} · ${entry.startsAt.toLocal()}'),
            trailing: Text(entry.daysUntil >= 0 ? '${entry.daysUntil}d' : 'Done'),
            onTap: () => context.eventNav.openOverview(entry.eventId),
          ),
      ],
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({required this.analytics});
  final PortfolioAnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrendRow('Revenue trend', analytics.revenueTrend),
          _TrendRow('Guest growth', analytics.guestGrowth),
          _TrendRow('Attendance', analytics.attendanceTrend),
          _TrendRow('Vendor costs', analytics.vendorCostTrend),
          _TrendRow('Ticket performance', analytics.ticketPerformance),
          _TrendRow('Profit trend', analytics.profitTrend),
          _TrendRow('Completion quality', analytics.completionQuality),
          _TrendRow('Budget efficiency', analytics.budgetEfficiency),
          if (analytics.eventComparisons.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.md),
            Text('Event comparisons', style: context.eosText.labelLarge),
            for (final row in analytics.eventComparisons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.title),
                trailing: Text(formatRevenue(row.revenueMinor)),
                onTap: () => context.eventNav.openOverview(row.eventId),
              ),
          ],
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow(this.label, this.points);
  final String label;
  final List<PortfolioTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final latest = points.last.value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(latest >= 1000 ? formatRevenue(latest.round()) : latest.toStringAsFixed(0)),
    );
  }
}

class _CopilotPanel extends StatelessWidget {
  const _CopilotPanel({required this.insights});
  final List<CopilotInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final insight in insights)
          Card(
            margin: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: ListTile(
              title: Text(insight.message),
              subtitle: Text(insight.category),
              trailing: insight.eventId != null ? const Icon(Icons.open_in_new, size: 18) : null,
              onTap: insight.eventId != null
                  ? () => context.eventNav.openOverview(insight.eventId!)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _VendorPanel extends StatelessWidget {
  const _VendorPanel({required this.rankings});
  final List<PortfolioVendorRank> rankings;

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
      return Text('No vendor data across events yet.', style: context.eosText.bodyMedium);
    }
    return Column(
      children: [
        for (final vendor in rankings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(vendor.businessName),
            subtitle: Text(
              '${vendor.service} · ${vendor.reliabilityScore}% reliable · ${vendor.eventsServed} events',
            ),
            trailing: Text(formatRevenue(vendor.averageCostMinor)),
          ),
      ],
    );
  }
}

class _GuestPanel extends StatelessWidget {
  const _GuestPanel({required this.insights});
  final PortfolioGuestInsight insights;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Repeat attendees'), trailing: Text('${insights.repeatAttendees}')),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('VIP guests'), trailing: Text('${insights.vipGuests}')),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('No-show trend'), trailing: Text('${insights.averageNoShowRate}%')),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('RSVP accept rate'), trailing: Text('${insights.rsvpAcceptRate}%')),
          if (insights.mostInvitedGuests.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text('Most invited', style: context.eosText.labelLarge),
            for (final guest in insights.mostInvitedGuests)
              Text('• $guest', style: context.eosText.bodySmall),
          ],
          TextButton(
            onPressed: () => context.eventNav.goGuestsHub(),
            child: const Text('Open Guests hub'),
          ),
        ],
      ),
    );
  }
}

class _FinancialPanel extends StatelessWidget {
  const _FinancialPanel({required this.financial});
  final PortfolioFinancialSnapshot financial;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        children: [
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Total profit'), trailing: Text(formatRevenue(financial.totalProfitMinor))),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Outstanding settlements'), trailing: Text(formatRevenue(financial.outstandingSettlementsMinor))),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Vendor spend'), trailing: Text(formatRevenue(financial.vendorSpendMinor))),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Budget accuracy'), trailing: Text('${financial.budgetAccuracyPct}%')),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Avg ticket yield'), trailing: Text(formatRevenue(financial.averageTicketYieldMinor))),
          if (financial.topRevenueEvents.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text('Top revenue events', style: context.eosText.labelLarge),
            for (final event in financial.topRevenueEvents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(event.title),
                trailing: Text(formatRevenue(event.revenueMinor)),
                onTap: () => context.eventNav.openOverview(event.eventId),
              ),
          ],
        ],
      ),
    );
  }
}

class _TemplatePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in portfolioEventTemplates)
          ActionChip(
            label: Text(kind.label),
            onPressed: () {
              final draft = buildTemplateDraft(kind);
              seedDuplicateEvent(ref, draft);
              context.push('/events/create');
            },
          ),
      ],
    );
  }
}

class _AutomationPanel extends StatelessWidget {
  const _AutomationPanel({required this.alerts});
  final List<AutomationAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Text('No automation alerts — portfolio looks healthy.', style: context.eosText.bodyMedium);
    }
    return Column(
      children: [
        for (final alert in alerts)
          EosAttentionBanner(
            headline: alert.title,
            message: alert.message,
            severity: alert.severity == 'high' ? 'WARNING' : 'INFO',
            actionLabel: 'Open event',
            onAction: () => context.eventNav.openOverview(alert.eventId),
          ),
      ],
    );
  }
}

class _BriefingPanel extends StatelessWidget {
  const _BriefingPanel({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
              child: Text(line, style: context.eosText.bodyMedium),
            ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: lines.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Weekly briefing copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy briefing'),
          ),
        ],
      ),
    );
  }
}
