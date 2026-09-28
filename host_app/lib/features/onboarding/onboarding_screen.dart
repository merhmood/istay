import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_host/core/onboarding/onboarding_provider.dart';

// Same host/size params as the seeded demo listing photos (see backend's
// seed.py) - Unsplash serves the raw file otherwise, which is unnecessarily
// heavy for a slide that's on screen for a couple of seconds.
const _photoParams = '?w=900&q=75&auto=format&fit=crop';

class _OnboardingPage {
  const _OnboardingPage({required this.icon, required this.imageId, required this.title, required this.body});

  final IconData icon;
  final String imageId;
  final String title;
  final String body;

  String get imageUrl => 'https://images.unsplash.com/$imageId$_photoParams';
}

const _pages = [
  _OnboardingPage(
    icon: LucideIcons.house,
    imageId: 'photo-1502672260266-1c1ef2d93688',
    title: 'List your place in minutes',
    body: 'Add photos, set your price, and go live the same day - no waiting on approval to start earning.',
  ),
  _OnboardingPage(
    icon: LucideIcons.users,
    imageId: 'photo-1522708323590-d24dbb6b0267',
    title: 'Reach guests across Nigeria',
    body: 'Your listing shows up to people searching by city, price, and the amenities that matter to them.',
  ),
  _OnboardingPage(
    icon: LucideIcons.calendarCheck,
    imageId: 'photo-1484154218962-a197022b5858',
    title: 'Manage bookings in one place',
    body: 'Accept or decline requests, block out dates, and message guests without switching apps.',
  ),
  _OnboardingPage(
    icon: LucideIcons.shieldCheck,
    imageId: 'photo-1493809842364-78817add7ffb',
    title: 'Get paid, safely',
    body: "Payouts sit in escrow and release after check-in, so you're covered if something goes wrong.",
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    ref.read(hasSeenOnboardingProvider.notifier).state = true;
    await markOnboardingSeen();
    if (mounted) context.go('/');
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextButton(
                  onPressed: isLast ? null : _finish,
                  style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: isLast ? 0 : 0.85)),
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: [for (final page in _pages) _OnboardingSlide(page: page)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: i == _page ? 22 : 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: i == _page ? 1 : 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark),
                      onPressed: _next,
                      child: Text(isLast ? 'Get started' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    // The image makes this slide tall enough to risk overflow on a short or
    // landscape viewport (the same failure the login screen hit earlier) -
    // scroll rather than crash when there isn't room, stay centred when there is.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 8, 30, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1.05,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: AppImage(url: page.imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                      // Kept the icon as a small badge rather than dropping it -
                      // it ties the photo back to the same glyph used for this
                      // topic elsewhere in the app (drawer items, section labels).
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: Icon(page.icon, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700, height: 1.25),
                ),
                const SizedBox(height: 12),
                Text(
                  page.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
