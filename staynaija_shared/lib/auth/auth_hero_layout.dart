import 'package:flutter/material.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

/// The gradient brand panel used at the top of both apps' login screens. Two
/// soft, oversized circles give it depth without needing an illustration
/// asset - a common device in this kind of hero when there is no photography
/// to lean on.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.subtitle, this.eyebrow, this.logoAsset});

  final String subtitle;

  /// A small pill above the wordmark - used by the host app to say "Host"
  /// without it looking like part of the brand name itself.
  final String? eyebrow;

  /// An app-bundled image shown above the wordmark, as a rounded app-icon tile.
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(top: -60, right: -70, child: _blob(220, Colors.white.withValues(alpha: 0.07))),
            Positioned(bottom: -90, left: -60, child: _blob(260, Colors.white.withValues(alpha: 0.05))),
            SafeArea(
              bottom: false,
              // The eyebrow pill plus wordmark plus subtitle, vertically
              // centred, overflowed by 11px in landscape: this Expanded hero
              // gets very little height once rotation eats most of the
              // screen, and a centred Column can't shrink itself to fit. The
              // LayoutBuilder+ConstrainedBox pattern below keeps the normal
              // (portrait, room to spare) case centred exactly as before,
              // while giving cramped cases - landscape, older/small screens -
              // a scroll fallback instead of an overflow error.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (logoAsset != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.asset(logoAsset!, width: 64, height: 64),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (eyebrow != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  eyebrow!.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            Text('iStay', style: brandTextStyle(fontSize: 42).copyWith(color: Colors.white)),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 15.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// The white, rounded-top sheet pinned to the bottom of the screen holding
/// the actual sign-in controls - the part of a login screen someone's thumb
/// is meant to reach for, so it lives where a thumb already rests, below
/// [AuthHero] rather than sharing a scrolling column with it.
class AuthSignInPanel extends StatelessWidget {
  const AuthSignInPanel({super.key, required this.error, required this.child});

  /// An auth error to show above [child], or null for none.
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('or', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
