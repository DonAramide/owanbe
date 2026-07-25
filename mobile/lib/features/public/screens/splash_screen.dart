import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_boot_state.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../eos/eos.dart';

/// Presentation-only splash — listens to [appBootstrapProvider] and navigates.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appBootstrapProvider, (previous, next) {
      if (!next.canNavigate || next.destination == null) return;
      if (!context.mounted) return;
      context.go(next.destination!);
    });

    final boot = ref.watch(appBootstrapProvider);
    // Navigate if already ready/error when this frame builds (listen only fires on changes).
    if (boot.canNavigate && boot.destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(boot.destination!);
      });
    }

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/branding/owambe_splash.jpg',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.celebration, color: EosColors.champagne, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Owanbe',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Event. Our People.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: EosColors.champagne,
                        fontWeight: FontWeight.w500,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Everything you need for an unforgettable celebration.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
