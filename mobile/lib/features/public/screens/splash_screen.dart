import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../eos/eos.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Timer(const Duration(seconds: 6), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final showWalkthrough = prefs.getBool('show_walkthrough') ?? true;
      if (!mounted) return;
      if (showWalkthrough) {
        context.go('/walkthrough');
      } else {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
