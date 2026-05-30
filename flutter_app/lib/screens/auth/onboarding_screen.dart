import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../services/haptic_service.dart';

const _kOnboardingSeen = 'onboarding_seen';

class _SlideData {
  final String image;
  final String title;
  final String myanmar;
  final String subtitle;

  const _SlideData({
    required this.image,
    required this.title,
    required this.myanmar,
    required this.subtitle,
  });
}

const _slides = [
  _SlideData(
    image: 'assets/onboarding/1_student_qr.png',
    title: 'Pay with QR Code',
    myanmar: 'QR Code ဖြင့် ငွေပေးချေပါ',
    subtitle: 'Students show their QR code at the canteen',
  ),
  _SlideData(
    image: 'assets/onboarding/2_seller_scan.png',
    title: 'Instant Payment',
    myanmar: 'ချက်ချင်း ငွေပေးချေမှု',
    subtitle: 'Sellers scan and charge — no cash needed',
  ),
  _SlideData(
    image: 'assets/onboarding/3_parent_notify.png',
    title: 'Parents Stay Informed',
    myanmar: 'မိဘများ သိရှိနိုင်ပါသည်',
    subtitle: 'Track spending and get instant notifications',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final nextPage = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  Future<void> _continue(BuildContext context) async {
    HapticService.success();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeen, true);
    if (context.mounted) context.go('/login');
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _continue(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastSlide = _currentPage == _slides.length - 1;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen PageView with background images
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                _stopAutoAdvance();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                return Image.asset(
                  _slides[index].image,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.50,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Skip button at top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: GestureDetector(
              onTap: () => _continue(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Text + indicators + button at bottom
          Positioned(
            bottom: 60,
            left: 28,
            right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _slides[_currentPage].title,
                    key: ValueKey('title_$_currentPage'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Myanmar text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _slides[_currentPage].myanmar,
                    key: ValueKey('myanmar_$_currentPage'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _slides[_currentPage].subtitle,
                    key: ValueKey('subtitle_$_currentPage'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Dot indicators
                Row(
                  children: List.generate(_slides.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.only(right: 8),
                      width: isActive ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),

                // Next / Get Started button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isLastSlide ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Check if onboarding has been seen
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingSeen) ?? false;
}
