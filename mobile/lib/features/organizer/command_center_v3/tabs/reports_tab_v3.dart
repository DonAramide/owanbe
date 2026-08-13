import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/auth_notifier.dart';
import '../../../../core/utils/export_helper.dart';
import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../analytics/organizer_analytics_api.dart';
import '../../analytics/organizer_analytics_providers.dart';
import '../../reports/organizer_reports_api.dart';
import '../widgets/cc_v3_health_cards.dart';

final _reportsFormatProvider = StateProvider.autoDispose.family<String, String>((ref, _) => 'csv');
final _reportsGuestStatusProvider = StateProvider.autoDispose.family<String, String>((ref, _) => '');
final _reportsTicketTypeProvider = StateProvider.autoDispose.family<String, String>((ref, _) => '');
final _reportsVendorStageProvider = StateProvider.autoDispose.family<String, String>((ref, _) => '');
final _reportsFromProvider = StateProvider.autoDispose.family<String, String>((ref, _) => '');
final _reportsToProvider = StateProvider.autoDispose.family<String, String>((ref, _) => '');

/// Phase 21 — Export Center. Read-only composition over Finance / Analytics / Ops / CRM.
class ReportsTabV3 extends ConsumerWidget {
  const ReportsTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(organizerEventReportsCatalogProvider(eventId));
    final portfolio = ref.watch(organizerAnalyticsPortfolioProvider);
    final format = ref.watch(_reportsFormatProvider(eventId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(organizerEventReportsCatalogProvider(eventId));
        ref.invalidate(organizerAnalyticsPortfolioProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Export Center', style: context.eosText.headlineSmall),
            ),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Download stakeholder packs from Operations, Finance, Analytics, and Vendor CRM. '
              'Numbers match those modules — reports never invent metrics.',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.lg),
            const CcV3SectionHeader(
              title: 'Filters',
              subtitle: 'Applied to attendance, guests, and vendor packs',
            ),
            _FiltersPanel(eventId: eventId),
            SizedBox(height: context.eos.spacing.md),
            Wrap(
              spacing: context.eos.spacing.sm,
              runSpacing: context.eos.spacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Format', style: context.eosText.labelMedium),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'csv', label: Text('CSV')),
                    ButtonSegment(value: 'xlsx', label: Text('Excel')),
                  ],
                  selected: {format},
                  onSelectionChanged: (s) {
                    ref.read(_reportsFormatProvider(eventId).notifier).state = s.first;
                  },
                ),
              ],
            ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(
              title: 'Event report packs',
              subtitle: 'Canonical sources only',
            ),
            catalog.when(
              loading: () => const _ReportsSkeleton(),
              error: (e, _) => EosAttentionBanner(
                headline: 'Catalog unavailable',
                message: '$e',
                severity: 'WARNING',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(organizerEventReportsCatalogProvider(eventId)),
              ),
              data: (items) => _PackList(
                eventId: eventId,
                items: items,
                format: format,
              ),
            ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(
              title: 'Portfolio comparison',
              subtitle: 'Reuse Analytics portfolio — multi-event summary',
            ),
            portfolio.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => EosAttentionBanner(
                headline: 'Portfolio unavailable',
                message: '$e',
                severity: 'WARNING',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(organizerAnalyticsPortfolioProvider),
              ),
              data: (items) => _PortfolioSection(items: items, format: format),
            ),
            SizedBox(height: context.eos.spacing.xl),
            EosAttentionBanner(
              headline: 'Report history & PDF',
              message:
                  'Export history and PDF/print views are deferred (Phase 21 P2). '
                  'CSV and Excel are the supported formats.',
              severity: 'INFO',
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersPanel extends ConsumerWidget {
  const _FiltersPanel({required this.eventId});
  final String eventId;

  Widget _field({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    String? hint,
    required void Function(String) onChanged,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 720;
        final from = _field(
          context: context,
          ref: ref,
          label: 'From (ISO date)',
          hint: '2026-01-01',
          onChanged: (v) => ref.read(_reportsFromProvider(eventId).notifier).state = v.trim(),
        );
        final to = _field(
          context: context,
          ref: ref,
          label: 'To (ISO date)',
          hint: '2026-12-31',
          onChanged: (v) => ref.read(_reportsToProvider(eventId).notifier).state = v.trim(),
        );
        final ticket = _field(
          context: context,
          ref: ref,
          label: 'Ticket type / tier',
          onChanged: (v) => ref.read(_reportsTicketTypeProvider(eventId).notifier).state = v.trim(),
        );
        final guest = _field(
          context: context,
          ref: ref,
          label: 'Guest RSVP status',
          hint: 'confirmed | pending | declined',
          onChanged: (v) => ref.read(_reportsGuestStatusProvider(eventId).notifier).state = v.trim(),
        );
        final vendor = _field(
          context: context,
          ref: ref,
          label: 'Vendor stage',
          hint: 'accepted | completed | …',
          onChanged: (v) => ref.read(_reportsVendorStageProvider(eventId).notifier).state = v.trim(),
        );
        if (wide) {
          return Row(
            children: [
              Expanded(child: from),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: to),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: ticket),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: guest),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: vendor),
            ],
          );
        }
        return Column(
          children: [
            from,
            SizedBox(height: context.eos.spacing.sm),
            to,
            SizedBox(height: context.eos.spacing.sm),
            ticket,
            SizedBox(height: context.eos.spacing.sm),
            guest,
            SizedBox(height: context.eos.spacing.sm),
            vendor,
          ],
        );
      },
    );
  }
}

class _PackList extends ConsumerWidget {
  const _PackList({
    required this.eventId,
    required this.items,
    required this.format,
  });

  final String eventId;
  final List<ReportCatalogEntry> items;
  final String format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final item in items) ...[
          _PackCard(eventId: eventId, item: item, format: format),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }
}

class _PackCard extends ConsumerStatefulWidget {
  const _PackCard({
    required this.eventId,
    required this.item,
    required this.format,
  });

  final String eventId;
  final ReportCatalogEntry item;
  final String format;

  @override
  ConsumerState<_PackCard> createState() => _PackCardState();
}

class _PackCardState extends ConsumerState<_PackCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final available = item.isAvailable;
    final fmt = item.formats.contains(widget.format) ? widget.format : 'csv';

    return Material(
      color: context.eosColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.md),
        child: Row(
          children: [
            Icon(
              available ? Icons.description_outlined : Icons.block_outlined,
              color: available ? context.eosColors.primary : context.eosColors.onSurfaceVariant,
            ),
            SizedBox(width: context.eos.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.eosText.titleSmall),
                  Text(
                    available
                        ? 'Source: ${item.source} · format: $fmt'
                        : 'Unavailable — ${item.reason ?? 'no canonical data'}',
                    style: context.eosText.bodySmall,
                  ),
                ],
              ),
            ),
            if (!available)
              Chip(
                label: const Text('Unavailable'),
                visualDensity: VisualDensity.compact,
                backgroundColor: context.eosColors.surfaceContainerHighest,
              )
            else
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _download(fmt),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(_busy ? '…' : 'Download'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(String fmt) async {
    setState(() => _busy = true);
    try {
      final session = ref.read(authSessionProvider);
      final result = await ref.read(organizerReportsApiProvider).exportEventPack(
            eventId: widget.eventId,
            pack: widget.item.id,
            format: fmt,
            from: ref.read(_reportsFromProvider(widget.eventId)),
            to: ref.read(_reportsToProvider(widget.eventId)),
            ticketType: ref.read(_reportsTicketTypeProvider(widget.eventId)),
            guestStatus: ref.read(_reportsGuestStatusProvider(widget.eventId)),
            vendorStage: ref.read(_reportsVendorStageProvider(widget.eventId)),
            session: session,
          );
      final path = await ExportHelper.downloadBytes(
        result.filename,
        result.bytes,
        mimeType: result.contentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null || path == result.filename
                ? 'Downloaded ${result.filename}'
                : 'Saved ${result.filename} → $path',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is OrganizerReportsApiException && e.code == 'REPORT_UNAVAILABLE'
          ? 'Unavailable'
          : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PortfolioSection extends ConsumerStatefulWidget {
  const _PortfolioSection({
    required this.items,
    required this.format,
  });

  final List<PortfolioAnalyticsItem> items;
  final String format;

  @override
  ConsumerState<_PortfolioSection> createState() => _PortfolioSectionState();
}

class _PortfolioSectionState extends ConsumerState<_PortfolioSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Text(
        'No events yet — create and sell tickets to compare portfolio performance.',
        style: context.eosText.bodySmall,
      );
    }

    final totalRevenue = widget.items.fold<int>(0, (a, i) => a + i.revenueMinor);
    final totalSold = widget.items.fold<int>(0, (a, i) => a + i.ticketsSold);
    final totalCheckedIn = widget.items.fold<int>(0, (a, i) => a + i.checkedIn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.sm,
          children: [
            _MetricChip(label: 'Events', value: '${widget.items.length}'),
            _MetricChip(label: 'Tickets sold', value: '$totalSold'),
            _MetricChip(label: 'Revenue', value: formatRevenue(totalRevenue)),
            _MetricChip(label: 'Checked in', value: '$totalCheckedIn'),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Event')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Sold'), numeric: true),
              DataColumn(label: Text('Revenue')),
              DataColumn(label: Text('Checked in'), numeric: true),
              DataColumn(label: Text('Attendance %'), numeric: true),
            ],
            rows: [
              for (final item in widget.items)
                DataRow(
                  cells: [
                    DataCell(Text(item.title)),
                    DataCell(Text(item.status)),
                    DataCell(Text('${item.ticketsSold}')),
                    DataCell(Text(formatRevenue(item.revenueMinor))),
                    DataCell(Text('${item.checkedIn}')),
                    DataCell(Text(item.attendancePct.toStringAsFixed(1))),
                  ],
                ),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _exportPortfolio,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(_busy ? 'Exporting…' : 'Download portfolio (${widget.format})'),
          ),
        ),
      ],
    );
  }

  Future<void> _exportPortfolio() async {
    setState(() => _busy = true);
    try {
      final session = ref.read(authSessionProvider);
      final result = await ref.read(organizerReportsApiProvider).exportPortfolio(
            format: widget.format,
            session: session,
          );
      final path = await ExportHelper.downloadBytes(
        result.filename,
        result.bytes,
        mimeType: result.contentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null || path == result.filename
                ? 'Downloaded ${result.filename}'
                : 'Saved ${result.filename} → $path',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: context.eosColors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
