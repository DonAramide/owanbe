import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/shared_preferences_provider.dart';
import '../../../eos/eos.dart';
import '../../../identity/experience_navigation.dart';

class WalkthroughScreen extends ConsumerStatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  ConsumerState<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends ConsumerState<WalkthroughScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _slides = [
    {
      'image': 'assets/branding/walkthrough1.jpg',
      'title': 'Welcome to Owanbe',
      'body': 'Everything you need for an unforgettable celebration. Discover premium events, manage invitations, and secure your digital entry passes.',
    },
    {
      'image': 'assets/branding/walkthrough2.jpg',
      'title': 'Flawless Event Planning',
      'body': 'Host and coordinate with ease. Manage seating arrangements, budgets, vendors, program schedules, and real-time check-in.',
    },
    {
      'image': 'assets/branding/walkthrough3.jpg',
      'title': 'Celebrate Together',
      'body': 'Connect with your guests, share beautiful event memories on the digital wall, and experience moments of absolute joy.',
    },
  ];

  Future<void> _completeWalkthrough() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('show_walkthrough', false);
    if (mounted) {
      context.go(ExperienceNavigation.entryWhenSignedOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == _slides.length - 1;

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      body: Column(
        children: [
          // Upper half PageView for sliding images
          Expanded(
            flex: 3,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                return Image.asset(
                  _slides[index]['image']!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
          ),
          // Lower half premium card
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: EosColors.plumDark,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Slide indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? EosColors.champagne : Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Text introducts
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _slides[_currentIndex]['title']!,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              _slides[_currentIndex]['body']!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _completeWalkthrough,
                        child: Text(
                          'Skip',
                          style: context.eosText.labelLarge?.copyWith(color: Colors.white60),
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (isLast) {
                            _completeWalkthrough();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: EosColors.champagne,
                          foregroundColor: EosColors.plumDark,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: Text(isLast ? 'Get Started' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
