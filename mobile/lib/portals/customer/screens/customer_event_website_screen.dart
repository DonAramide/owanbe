import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/event_website_models.dart';
import '../providers/event_website_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';
import '../widgets/website/event_website_preview_frame.dart';

/// Phase 2A — Event website builder at `/events/:eventId/website`.
class CustomerEventWebsiteScreen extends ConsumerStatefulWidget {
  const CustomerEventWebsiteScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventWebsiteScreen> createState() => _CustomerEventWebsiteScreenState();
}

class _CustomerEventWebsiteScreenState extends ConsumerState<CustomerEventWebsiteScreen> {
  EventWebsiteConfig? _draft;
  bool _busy = false;
  bool _mobilePreview = true;

  Future<void> _save(EventWebsiteConfig draft) async {
    setState(() => _busy = true);
    try {
      final updated = await ref.read(eventWebsiteApiProvider).patch(widget.eventId, draft.toPatchBody());
      setState(() => _draft = updated);
      refreshEventWebsite(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(EventWebsiteConfig draft) async {
    setState(() => _busy = true);
    try {
      await _save(draft);
      final updated = await ref.read(eventWebsiteApiProvider).publish(widget.eventId);
      setState(() => _draft = updated);
      refreshEventWebsite(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Published at ${updated.publicUrl}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpublish() async {
    setState(() => _busy = true);
    try {
      final updated = await ref.read(eventWebsiteApiProvider).unpublish(widget.eventId);
      setState(() => _draft = updated);
      refreshEventWebsite(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Public URL copied')));
  }

  @override
  Widget build(BuildContext context) {
    final website = ref.watch(eventWebsiteProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.eventDetail(widget.eventId));
            }
          },
        ),
        title: const Text('Event website'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: website.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load website',
              message: error.toString(),
              actionLabel: 'Back to event',
              onAction: () => context.go(CustomerRoutes.eventDetail(widget.eventId)),
            ),
          ],
        ),
        data: (config) {
          final draft = _draft ?? config;
          if (_draft == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _draft = config);
            });
          }

          return RefreshIndicator(
            onRefresh: () async {
              refreshEventWebsite(ref);
              await ref.read(eventWebsiteProvider(widget.eventId).future);
            },
            child: ListView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                _StatusDashboard(
                  config: draft,
                  onCopy: () => _copyUrl(draft.publicUrl),
                  onShare: () => _copyUrl(draft.publicUrl),
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Template gallery',
                  subtitle: 'Structured layouts — no drag-and-drop editing.',
                ),
                _TemplateGallery(
                  selectedId: draft.templateId,
                  onSelect: (id) async {
                    final next = draft.copyWith(templateId: id);
                    setState(() => _draft = next);
                    await _save(next);
                  },
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Website sections',
                  subtitle: 'Toggle what appears on your public microsite.',
                ),
                _SectionsManager(
                  sections: draft.sections,
                  onChanged: (key, value) async {
                    final nextSections = Map<String, bool>.from(draft.sections)..[key] = value;
                    final next = draft.copyWith(sections: nextSections);
                    setState(() => _draft = next);
                    await _save(next);
                  },
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Theme customization',
                  subtitle: 'Color, typography, and imagery.',
                ),
                _ThemePanel(
                  themeColor: draft.themeColor,
                  fontPair: draft.fontPair,
                  coverUrl: draft.coverImageUrl,
                  heroUrl: draft.heroImageUrl,
                  onThemeColor: (c) async {
                    final next = draft.copyWith(themeColor: c);
                    setState(() => _draft = next);
                    await _save(next);
                  },
                  onFontPair: (f) async {
                    final next = draft.copyWith(fontPair: f);
                    setState(() => _draft = next);
                    await _save(next);
                  },
                  onCoverUrl: (u) async {
                    final next = draft.copyWith(coverImageUrl: u);
                    setState(() => _draft = next);
                    await _save(next);
                  },
                  onHeroUrl: (u) async {
                    final next = draft.copyWith(heroImageUrl: u);
                    setState(() => _draft = next);
                    await _save(next);
                  },
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Live preview',
                  subtitle: 'See how guests will experience your site.',
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Mobile'), icon: Icon(Icons.phone_iphone)),
                    ButtonSegment(value: false, label: Text('Desktop'), icon: Icon(Icons.desktop_mac_outlined)),
                  ],
                  selected: {_mobilePreview},
                  onSelectionChanged: (s) => setState(() => _mobilePreview = s.first),
                ),
                SizedBox(height: context.eos.spacing.md),
                Center(
                  child: EventWebsitePreviewFrame(config: draft, compact: _mobilePreview),
                ),
                SizedBox(height: context.eos.spacing.xl),
                if (draft.isPublished)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _unpublish,
                    icon: const Icon(Icons.unpublished_outlined),
                    label: const Text('Revert to draft'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _publish(draft),
                    icon: const Icon(Icons.public),
                    label: const Text('Publish website'),
                  ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  'Publishing generates your public URL (e.g. https://owanbe.com/e/${draft.publicSlug}).',
                  style: context.eosText.bodySmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.eos.spacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusDashboard extends StatelessWidget {
  const _StatusDashboard({
    required this.config,
    required this.onCopy,
    required this.onShare,
  });

  final EventWebsiteConfig config;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                config.isPublished ? Icons.check_circle : Icons.edit_note_outlined,
                color: config.isPublished ? EosColors.success : EosColors.warning,
              ),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Website status', style: context.eosText.titleSmall),
                    Text(
                      config.isPublished ? 'Published' : 'Draft',
                      style: context.eosText.bodyMedium?.copyWith(
                        color: config.isPublished ? EosColors.success : EosColors.slate500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FinanceStatusStyleChip(label: config.isPublished ? 'LIVE' : 'DRAFT'),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          Text('Public URL', style: context.eosText.labelMedium),
          SizedBox(height: context.eos.spacing.xxs),
          SelectableText(
            config.publicUrl,
            style: context.eosText.bodyMedium?.copyWith(color: context.eosColors.primary),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy link'),
              ),
              OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Local status chip — avoids finance module import.
class FinanceStatusStyleChip extends StatelessWidget {
  const FinanceStatusStyleChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.eosColors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: context.eosText.labelSmall),
    );
  }
}

class _TemplateGallery extends StatelessWidget {
  const _TemplateGallery({required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: EventWebsiteTemplate.gallery.length,
        separatorBuilder: (_, __) => SizedBox(width: context.eos.spacing.sm),
        itemBuilder: (context, i) {
          final t = EventWebsiteTemplate.gallery[i];
          final selected = t.id == selectedId;
          Color accent;
          try {
            accent = Color(int.parse('FF${t.accentColor.replaceFirst('#', '')}', radix: 16));
          } catch (_) {
            accent = EosColors.plum;
          }
          return SizedBox(
            width: 160,
            child: EosSurfaceCard(
              onTap: () => onSelect(t.id),
              accentColor: selected ? accent : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.icon, style: const TextStyle(fontSize: 24)),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(t.label, style: context.eosText.titleSmall),
                  Text(t.description, style: context.eosText.bodySmall, maxLines: 2),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionsManager extends StatelessWidget {
  const _SectionsManager({required this.sections, required this.onChanged});

  final Map<String, bool> sections;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        children: EventWebsiteSectionKeys.all.map((key) {
          final label = EventWebsiteSectionKeys.labels[key] ?? key;
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            value: sections[key] ?? false,
            onChanged: (v) => onChanged(key, v),
          );
        }).toList(),
      ),
    );
  }
}

class _ThemePanel extends StatelessWidget {
  const _ThemePanel({
    required this.themeColor,
    required this.fontPair,
    required this.coverUrl,
    required this.heroUrl,
    required this.onThemeColor,
    required this.onFontPair,
    required this.onCoverUrl,
    required this.onHeroUrl,
  });

  final String themeColor;
  final String fontPair;
  final String? coverUrl;
  final String? heroUrl;
  final ValueChanged<String> onThemeColor;
  final ValueChanged<String> onFontPair;
  final ValueChanged<String?> onCoverUrl;
  final ValueChanged<String?> onHeroUrl;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme color', style: context.eosText.labelLarge),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EventWebsiteThemeColors.presets.map((hex) {
              Color c;
              try {
                c = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
              } catch (_) {
                c = EosColors.plum;
              }
              final selected = themeColor.toUpperCase() == hex.toUpperCase();
              return InkWell(
                onTap: () => onThemeColor(hex),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: Colors.black, width: 2) : null,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Font pair', style: context.eosText.labelLarge),
          SizedBox(height: context.eos.spacing.sm),
          DropdownButtonFormField<String>(
            value: EventWebsiteFontPairs.options.any((p) => p.$1 == fontPair)
                ? fontPair
                : EventWebsiteFontPairs.options.first.$1,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: EventWebsiteFontPairs.options
                .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                .toList(),
            onChanged: (v) {
              if (v != null) onFontPair(v);
            },
          ),
          SizedBox(height: context.eos.spacing.lg),
          _UrlField(
            label: 'Cover image URL',
            initialValue: coverUrl,
            onSave: onCoverUrl,
          ),
          SizedBox(height: context.eos.spacing.md),
          _UrlField(
            label: 'Hero image URL',
            initialValue: heroUrl,
            onSave: onHeroUrl,
          ),
        ],
      ),
    );
  }
}

class _UrlField extends StatefulWidget {
  const _UrlField({required this.label, required this.initialValue, required this.onSave});

  final String label;
  final String? initialValue;
  final ValueChanged<String?> onSave;

  @override
  State<_UrlField> createState() => _UrlFieldState();
}

class _UrlFieldState extends State<_UrlField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant _UrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
              hintText: 'https://…',
            ),
            onSubmitted: (v) => widget.onSave(v.trim().isEmpty ? null : v.trim()),
          ),
        ),
        IconButton(
          tooltip: 'Save URL',
          onPressed: () {
            final v = _controller.text.trim();
            widget.onSave(v.isEmpty ? null : v);
          },
          icon: const Icon(Icons.check),
        ),
      ],
    );
  }
}
