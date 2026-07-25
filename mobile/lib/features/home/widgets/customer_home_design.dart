import 'dart:ui';

import 'package:flutter/material.dart';

/// Approved Customer Home — palette and layout tokens from concept handoff.
abstract final class CustomerHomeDesign {
  static const gold = Color(0xFFE1B35B);
  static const goldDeep = Color(0xFFC9A04A);
  static const plumDeep = Color(0xFF1A0B24);
  static const plumMid = Color(0xFF2D1635);
  static const plumCard = Color(0xFF3A2550);

  /// Spacious concept proportions (not Material defaults).
  static const headlineSize = 40.0;
  static const headlineHeight = 1.18;
  static const bodySize = 15.0;
  static const bodyHeight = 1.7;
  static const horizontalPad = 28.0;

  /// Cinematic celebration photo — NEVER the brand logo mark.
  static const backgroundAsset = 'assets/branding/owanbe_celebration_bg.jpg';

  static const introCopy =
      'Owanbe is your all-in-one platform to discover, plan and manage '
      'unforgettable events with ease.\n\n'
      'Whether you want to attend, organize, or offer services—we\'ve got you covered.';
}

/// Circular gold-bordered three-dot control (approved concept).
class CustomerHomeThreeDotButton extends StatelessWidget {
  const CustomerHomeThreeDotButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CustomerHomeDesign.gold.withValues(alpha: 0.9), width: 1.4),
            color: Colors.black.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.more_vert, color: CustomerHomeDesign.gold, size: 20),
        ),
      ),
    );
  }
}

/// Full-width gold stadium CTA — "Explore Owanbe".
class CustomerHomeExploreButton extends StatelessWidget {
  const CustomerHomeExploreButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8C56E),
            CustomerHomeDesign.gold,
            CustomerHomeDesign.goldDeep,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: CustomerHomeDesign.gold.withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Explore Owanbe',
                  style: TextStyle(
                    color: Color(0xFF1A0B24),
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 0.1,
                    height: 1,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF1A0B24), size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action — play icon + gold label.
class CustomerHomeSeeHowItWorks extends StatelessWidget {
  const CustomerHomeSeeHowItWorks({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: CustomerHomeDesign.gold, width: 1.5),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: CustomerHomeDesign.gold, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'See how it works',
              style: TextStyle(
                color: CustomerHomeDesign.gold,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Concept wordmark — gold crown above white "Owanbe" (not the app-icon asset).
class CustomerHomeLogo extends StatelessWidget {
  const CustomerHomeLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, color: CustomerHomeDesign.gold, size: 14),
            SizedBox(height: 0),
          ],
        ),
        SizedBox(width: 2),
        Text(
          'Owanbe',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Shared cinematic background + purple gradient overlay.
class CustomerHomeBackground extends StatelessWidget {
  const CustomerHomeBackground({
    super.key,
    required this.child,
    this.blurBackground = false,
    this.parallaxOffset = Offset.zero,
    this.alignment = const Alignment(0, -0.35),
  });

  final Widget child;
  final bool blurBackground;
  final Offset parallaxOffset;

  /// Keep faces / lights in the upper frame like the concept.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    Widget bg = Transform.translate(
      offset: parallaxOffset,
      child: Transform.scale(
        scale: blurBackground ? 1.12 : 1.08,
        child: Image.asset(
          CustomerHomeDesign.backgroundAsset,
          fit: BoxFit.cover,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: CustomerHomeDesign.plumDeep,
            child: Image.asset(
              'assets/branding/walkthrough2.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    if (blurBackground) {
      bg = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            CustomerHomeDesign.plumDeep.withValues(alpha: 0.35),
            BlendMode.darken,
          ),
          child: bg,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Concept: photo clear at top; ~60% dark purple from bottom.
              stops: blurBackground
                  ? const [0.0, 0.25, 0.55, 1.0]
                  : const [0.0, 0.28, 0.52, 0.78, 1.0],
              colors: blurBackground
                  ? [
                      CustomerHomeDesign.plumDeep.withValues(alpha: 0.55),
                      CustomerHomeDesign.plumDeep.withValues(alpha: 0.78),
                      CustomerHomeDesign.plumDeep.withValues(alpha: 0.92),
                      CustomerHomeDesign.plumDeep.withValues(alpha: 0.97),
                    ]
                  : [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.12),
                      CustomerHomeDesign.plumDeep.withValues(alpha: 0.55),
                      CustomerHomeDesign.plumDeep.withValues(alpha: 0.88),
                      CustomerHomeDesign.plumDeep.withValues(alpha: 0.96),
                    ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Short solid gold rule under the headline (concept).
class CustomerHomeGoldDivider extends StatelessWidget {
  const CustomerHomeGoldDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 3.5,
      margin: const EdgeInsets.only(top: 18, bottom: 22),
      decoration: BoxDecoration(
        color: CustomerHomeDesign.gold,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Role card palette from approved concept.
class CustomerHomeRoleStyle {
  const CustomerHomeRoleStyle({
    required this.iconBg,
    required this.iconColor,
  });

  final Color iconBg;
  final Color iconColor;

  static const attendee = CustomerHomeRoleStyle(
    iconBg: Color(0xFF5B3A8C),
    iconColor: CustomerHomeDesign.gold,
  );
  static const organizer = CustomerHomeRoleStyle(
    iconBg: Color(0xFFE07A2F),
    iconColor: Colors.white,
  );
  static const vendor = CustomerHomeRoleStyle(
    iconBg: Color(0xFF2E8B57),
    iconColor: Colors.white,
  );
}
