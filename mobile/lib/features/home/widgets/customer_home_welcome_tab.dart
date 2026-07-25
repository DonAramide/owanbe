import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../screens/join_owanbe_as_screen.dart';
import 'customer_home_design.dart';

/// Screen 1 — approved concept welcome (spacious premium landing).
class CustomerHomeWelcomeTab extends StatefulWidget {
  const CustomerHomeWelcomeTab({super.key});

  @override
  State<CustomerHomeWelcomeTab> createState() => _CustomerHomeWelcomeTabState();
}

class _CustomerHomeWelcomeTabState extends State<CustomerHomeWelcomeTab>
    with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _ambient.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _openJoinAs() => JoinOwanbeAsScreen.open(context);

  Future<void> _seeHowItWorks() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: CustomerHomeDesign.plumDeep.withValues(alpha: 0.94),
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'How Owanbe works',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      CustomerHomeDesign.introCopy,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.6,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    CustomerHomeExploreButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openJoinAs();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final headlineSize = size.width < 360
        ? 34.0
        : size.width < 400
            ? 38.0
            : CustomerHomeDesign.headlineSize;
    final fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    final slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(fade);

    return AnimatedBuilder(
      animation: _ambient,
      builder: (context, _) {
        final t = _ambient.value;
        final parallax = Offset(math.sin(t * math.pi * 2) * 6, math.cos(t * math.pi * 2) * 4);
        return CustomerHomeBackground(
          parallaxOffset: parallax,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _FloatingParticlesPainter(progress: t)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CustomerHomeDesign.horizontalPad,
                    8,
                    CustomerHomeDesign.horizontalPad,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const CustomerHomeLogo(),
                          const Spacer(),
                          CustomerHomeThreeDotButton(onPressed: _openJoinAs),
                        ],
                      ),
                      Expanded(
                        child: FadeTransition(
                          opacity: fade,
                          child: SlideTransition(
                            position: slide,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Concept: large empty upper photo plane, then copy block.
                                const Spacer(flex: 5),
                                RichText(
                                  textAlign: TextAlign.left,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: headlineSize,
                                      fontWeight: FontWeight.w800,
                                      height: CustomerHomeDesign.headlineHeight,
                                      letterSpacing: -0.6,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: 'Bringing every event\n',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      TextSpan(
                                        text: 'to your doorstep.',
                                        style: TextStyle(color: CustomerHomeDesign.gold),
                                      ),
                                    ],
                                  ),
                                ),
                                const CustomerHomeGoldDivider(),
                                Text(
                                  CustomerHomeDesign.introCopy,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: CustomerHomeDesign.bodySize,
                                    height: CustomerHomeDesign.bodyHeight,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Spacer(flex: 4),
                                CustomerHomeExploreButton(onPressed: _openJoinAs),
                                const SizedBox(height: 4),
                                CustomerHomeSeeHowItWorks(onPressed: _seeHowItWorks),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingParticlesPainter extends CustomPainter {
  _FloatingParticlesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rnd = math.Random(11);
    for (var i = 0; i < 18; i++) {
      final baseX = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height * 0.55;
      final drift = math.sin((progress * math.pi * 2) + i) * 8;
      final r = 1.1 + (i % 3) * 0.5;
      paint.color = Color.lerp(
        CustomerHomeDesign.gold.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.16),
        (i % 4) / 4,
      )!;
      canvas.drawCircle(
        Offset(baseX + drift, (baseY + progress * 28 + i * 9) % (size.height * 0.6)),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
