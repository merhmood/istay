import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The three provider buttons, in the order guests/hosts here are most
/// likely to actually have an account ready: Google is near-universal on
/// Android, Apple matters for iOS users, Facebook last since it is the
/// least likely to be the account someone reaches for first.
///
/// All three share this file's own `_ProviderButton` chrome, including the
/// app's Poppins type, rather than mixing in Apple's official
/// `SignInWithAppleButton` widget as-is. That widget hardcodes its label to
/// `.SF Pro Text` with `inherit: false` - a deliberate Apple HIG requirement
/// for the *exact* button Apple ships, not an oversight, but it also means
/// there is no supported way to make its text match the other two buttons.
/// Since this app is Android-first and visual consistency across one screen
/// matters more here than iOS button-compliance that isn't being submitted
/// anywhere yet, the logo is kept authentic - `AppleLogoPainter` is Apple's
/// own vector path, imported from the same package - while the button
/// chrome around it matches Google's and Facebook's exactly. Revisit this if
/// the app ever ships to the App Store, where Apple's review guidelines
/// expect their own button verbatim.
/// Google and Facebook have no equivalent official Flutter widget, so
/// [googleLogoAsset] and [facebookLogoAsset] point at each app's own bundled
/// copy of that provider's real logo (both apps register the same two files
/// under `assets/`) rather than a home-drawn stand-in.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
    required this.onFacebook,
    required this.googleLogoAsset,
    required this.facebookLogoAsset,
    this.loadingProvider,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onFacebook;

  final String googleLogoAsset;
  final String facebookLogoAsset;

  /// Which provider (if any) is mid-sign-in, so only that one button shows a
  /// spinner rather than freezing all three while one is working.
  final String? loadingProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProviderButton(
          label: 'Continue with Google',
          background: Colors.white,
          foreground: const Color(0xFF1F1F1F),
          border: const Color(0xFFDADCE0),
          logo: Image.asset(googleLogoAsset, width: 20, height: 20),
          onTap: onGoogle,
          isLoading: loadingProvider == 'google',
        ),
        const SizedBox(height: 10),
        _ProviderButton(
          label: 'Continue with Apple',
          background: Colors.black,
          foreground: Colors.white,
          logo: const SizedBox(
            width: 16,
            height: 20,
            child: CustomPaint(painter: AppleLogoPainter(color: Colors.white)),
          ),
          onTap: onApple,
          isLoading: loadingProvider == 'apple',
        ),
        const SizedBox(height: 10),
        _ProviderButton(
          label: 'Continue with Facebook',
          background: const Color(0xFF1877F2),
          foreground: Colors.white,
          logo: Image.asset(facebookLogoAsset, width: 20, height: 20),
          onTap: onFacebook,
          isLoading: loadingProvider == 'facebook',
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.logo,
    required this.onTap,
    required this.isLoading,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final Widget logo;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border ?? Colors.transparent),
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
        ),
        child: isLoading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: logo),
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: foreground)),
                ],
              ),
      ),
    );
  }
}
