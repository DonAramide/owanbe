import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../../../features/organizer/models/organizer_models.dart';
import '../../models/home_hub_models.dart';
import '../../models/invitation_template_models.dart';

/// Renders a portrait invitation card with celebrant photo, name, and location.
class InvitationCardRenderer extends StatelessWidget {
  const InvitationCardRenderer({
    super.key,
    required this.template,
    required this.event,
    this.compact = false,
    this.showMotionBadge = true,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final bool compact;
  final bool showMotionBadge;

  String get _location {
    final venue = event.venueName.isNotEmpty ? event.venueName : event.venue;
    if (venue.isEmpty) return event.city;
    if (event.city.isEmpty) return venue;
    return '$venue · ${event.city}';
  }

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 10.0 : 16.0;
    return AspectRatio(
      aspectRatio: 5 / 7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _layoutBody(context),
            if (template.hasAnimation && showMotionBadge)
              Positioned(
                top: compact ? 4 : 8,
                right: compact ? 4 : 8,
                child: _MotionBadge(compact: compact),
              ),
            if (template.isPremium && compact)
              Positioned(
                top: 4,
                left: 4,
                child: _TierDot(tier: template.tier),
              ),
          ],
        ),
      ),
    );
  }

  Widget _layoutBody(BuildContext context) {
    return switch (template.photoLayout) {
      InvitationPhotoLayout.topHero => _TopHeroLayout(
          template: template,
          event: event,
          location: _location,
          compact: compact,
        ),
      InvitationPhotoLayout.circleInset => _CircleInsetLayout(
          template: template,
          event: event,
          location: _location,
          compact: compact,
        ),
      InvitationPhotoLayout.fullBleed => _FullBleedLayout(
          template: template,
          event: event,
          location: _location,
          compact: compact,
        ),
      InvitationPhotoLayout.floralFrame => _FloralFrameLayout(
          template: template,
          event: event,
          location: _location,
          compact: compact,
        ),
      InvitationPhotoLayout.splitPortrait => _SplitPortraitLayout(
          template: template,
          event: event,
          location: _location,
          compact: compact,
        ),
      InvitationPhotoLayout.none => _GradientLayout(
          template: template,
          event: event,
          location: _location,
          compact: compact,
        ),
    };
  }
}

class _TopHeroLayout extends StatelessWidget {
  const _TopHeroLayout({
    required this.template,
    required this.event,
    required this.location,
    required this.compact,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Color(template.accentColor);
    return ColoredBox(
      color: Color(template.gradientStart),
      child: Column(
        children: [
          Expanded(
            flex: 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CelebrantPhoto(event: event, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: accent.withValues(alpha: 0.6), width: compact ? 2 : 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 9,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 6 : 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(template.gradientStart), Color(template.gradientEnd)],
                ),
              ),
              child: _InviteTextBlock(
                event: event,
                location: location,
                accent: accent,
                compact: compact,
                align: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleInsetLayout extends StatelessWidget {
  const _CircleInsetLayout({
    required this.template,
    required this.event,
    required this.location,
    required this.compact,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Color(template.accentColor);
    final textColor = _contrastOn(Color(template.gradientEnd));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(template.gradientStart), Color(template.gradientEnd)],
        ),
      ),
      padding: EdgeInsets.all(compact ? 6 : 16),
      child: Column(
        children: [
          Text(
            'You\'re invited',
            style: TextStyle(
              color: accent,
              fontSize: compact ? 7 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: compact ? 4 : 10),
          Container(
            padding: EdgeInsets.all(compact ? 2 : 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: compact ? 2 : 3),
            ),
            child: ClipOval(
              child: SizedBox(
                width: compact ? 44 : 88,
                height: compact ? 44 : 88,
                child: CelebrantPhoto(event: event, fit: BoxFit.cover),
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 10),
          Expanded(
            child: _InviteTextBlock(
              event: event,
              location: location,
              accent: accent,
              textColor: textColor,
              compact: compact,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullBleedLayout extends StatelessWidget {
  const _FullBleedLayout({
    required this.template,
    required this.event,
    required this.location,
    required this.compact,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Color(template.accentColor);
    return Stack(
      fit: StackFit.expand,
      children: [
        CelebrantPhoto(event: event, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0.35, 1],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(compact ? 6 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: compact ? 2 : 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Save the date',
                  style: TextStyle(
                    color: _contrastOn(accent),
                    fontSize: compact ? 6 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              _InviteTextBlock(
                event: event,
                location: location,
                accent: accent,
                textColor: Colors.white,
                compact: compact,
                align: TextAlign.start,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloralFrameLayout extends StatelessWidget {
  const _FloralFrameLayout({
    required this.template,
    required this.event,
    required this.location,
    required this.compact,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Color(template.accentColor);
    final bg = Color(template.gradientStart);
    return Container(
      color: bg,
      padding: EdgeInsets.all(compact ? 5 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          border: Border.all(color: accent, width: compact ? 1 : 2),
          borderRadius: BorderRadius.circular(compact ? 6 : 10),
        ),
        child: Stack(
          children: [
            ..._floralCorners(accent, compact),
            Padding(
              padding: EdgeInsets.all(compact ? 5 : 12),
              child: Column(
                children: [
                  Text(
                    'Celebration',
                    style: TextStyle(
                      color: accent,
                      fontSize: compact ? 7 : 11,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: compact ? 3 : 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(compact ? 4 : 8),
                      child: CelebrantPhoto(event: event, fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(height: compact ? 3 : 8),
                  _InviteTextBlock(
                    event: event,
                    location: location,
                    accent: accent,
                    textColor: const Color(0xFF1E293B),
                    compact: compact,
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _floralCorners(Color accent, bool compact) {
    final icon = Icon(Icons.local_florist, color: accent.withValues(alpha: 0.55), size: compact ? 10 : 16);
    return [
      Positioned(top: 2, left: 2, child: icon),
      Positioned(top: 2, right: 2, child: Transform.flip(flipX: true, child: icon)),
      Positioned(bottom: 2, left: 2, child: Transform.flip(flipY: true, child: icon)),
      Positioned(bottom: 2, right: 2, child: Transform.flip(flipX: true, flipY: true, child: icon)),
    ];
  }
}

class _SplitPortraitLayout extends StatelessWidget {
  const _SplitPortraitLayout({
    required this.template,
    required this.event,
    required this.location,
    required this.compact,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Color(template.accentColor);
    return Column(
      children: [
        Expanded(child: CelebrantPhoto(event: event, fit: BoxFit.cover)),
        Container(
          height: compact ? 52 : 110,
          width: double.infinity,
          color: const Color(0xFFFDF8F3),
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 14, vertical: compact ? 4 : 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: accent, width: compact ? 2 : 3)),
            ),
            child: _InviteTextBlock(
              event: event,
              location: location,
              accent: accent,
              textColor: const Color(0xFF1E293B),
              compact: compact,
              align: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientLayout extends StatelessWidget {
  const _GradientLayout({
    required this.template,
    required this.event,
    required this.location,
    required this.compact,
  });

  final InvitationTemplate template;
  final OrganizerEvent event;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final end = Color(template.gradientEnd);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [Color(template.gradientStart), end],
        ),
      ),
      padding: EdgeInsets.all(compact ? 6 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 80,
                width: double.infinity,
                child: CelebrantPhoto(event: event, fit: BoxFit.cover),
              ),
            ),
          if (!compact) SizedBox(height: 10),
          const Spacer(),
          _InviteTextBlock(
            event: event,
            location: location,
            accent: Color(template.accentColor),
            textColor: _contrastOn(end),
            compact: compact,
            align: TextAlign.start,
          ),
        ],
      ),
    );
  }
}

class _InviteTextBlock extends StatelessWidget {
  const _InviteTextBlock({
    required this.event,
    required this.location,
    required this.accent,
    required this.compact,
    required this.align,
    this.textColor,
  });

  final OrganizerEvent event;
  final String location;
  final Color accent;
  final bool compact;
  final TextAlign align;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final primary = textColor ?? const Color(0xFF1E293B);
    final titleSize = compact ? 9.0 : 18.0;
    final bodySize = compact ? 6.0 : 11.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          textAlign: align,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primary,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            height: 1.1,
            fontFamily: 'Georgia',
          ),
        ),
        if (event.tagline.isNotEmpty && !compact) ...[
          const SizedBox(height: 4),
          Text(
            event.tagline,
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: primary.withValues(alpha: 0.75), fontSize: bodySize),
          ),
        ],
        SizedBox(height: compact ? 2 : 6),
        Text(
          formatEventDate(event.startsAt),
          textAlign: align,
          style: TextStyle(color: accent, fontSize: bodySize, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: compact ? 1 : 4),
        Row(
          mainAxisAlignment: align == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: compact ? 7 : 12, color: accent),
            SizedBox(width: compact ? 2 : 4),
            Flexible(
              child: Text(
                location,
                textAlign: align,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: primary.withValues(alpha: 0.85), fontSize: bodySize),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CelebrantPhoto extends StatelessWidget {
  const CelebrantPhoto({super.key, required this.event, this.fit = BoxFit.cover});

  final OrganizerEvent event;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = event.celebrantImageUrl;
    if (url != null && url.isNotEmpty) {
      return _CelebrantImage(url: url, fit: fit);
    }
    return _PhotoPlaceholder(event: event);
  }
}

class _CelebrantImage extends StatelessWidget {
  const _CelebrantImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, fit: fit, width: double.infinity, height: double.infinity);
      } catch (_) {
        return const _PhotoPlaceholder();
      }
    }
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.event});

  final OrganizerEvent? event;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(event?.title ?? '');
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4B2C6F), Color(0xFF7B4FA3)],
        ),
      ),
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(Icons.person_outline, color: Colors.white.withValues(alpha: 0.7), size: 36)
          : Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  String _initials(String title) {
    final parts = title.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return parts.map((p) => p[0].toUpperCase()).join();
  }
}

class _MotionBadge extends StatelessWidget {
  const _MotionBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.white, size: compact ? 8 : 12),
          if (!compact) ...[
            const SizedBox(width: 3),
            const Text('Motion', style: TextStyle(color: Colors.white, fontSize: 9)),
          ],
        ],
      ),
    );
  }
}

class _TierDot extends StatelessWidget {
  const _TierDot({required this.tier});

  final InvitationTemplateTier tier;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tier) {
      InvitationTemplateTier.threeD => EosColors.info,
      InvitationTemplateTier.fourD => EosColors.plum,
      _ => EosColors.champagne,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        tier.badge,
        style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Color _contrastOn(Color bg) {
  return bg.computeLuminance() > 0.55 ? const Color(0xFF0F172A) : Colors.white;
}
