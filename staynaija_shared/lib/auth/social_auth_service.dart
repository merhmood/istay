import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// A provider's own signed token, ready to hand to `AuthRepository.socialLogin`.
///
/// Deliberately never carries an email or name as something to *trust* on its
/// own - [token] is what the backend actually verifies. [fullName] is passed
/// through only because Apple hands it over exactly once, on the very first
/// authorisation, and would be lost forever if not captured here and sent
/// along immediately.
class SocialCredential {
  const SocialCredential({required this.provider, required this.token, this.fullName});

  final String provider;
  final String token;
  final String? fullName;
}

/// Thin wrapper around three unrelated SDKs, so both apps call one thing and
/// the awkward per-provider setup lives in exactly one place.
///
/// Every method here needs the *app* it runs in to be configured with real
/// provider credentials - this class only calls the SDKs, it cannot supply
/// what they need to work:
///
/// - **Google**: an OAuth client registered in Google Cloud Console for this
///   app's package name + SHA-1 signing fingerprint (Android) / bundle id
///   (iOS). Nothing to add on the Flutter side beyond the client id itself,
///   which `google_sign_in` picks up from `google-services.json` (Android) or
///   the reversed-client-id URL scheme (iOS) - see that package's own setup
///   guide, since the exact file placement is unrelated to this class.
/// - **Apple**: an App ID with the "Sign in with Apple" capability enabled in
///   an Apple Developer account, plus (for Android) a Services ID configured
///   as a web-based fallback, since Apple's native flow only exists on Apple
///   platforms.
/// - **Facebook**: an app created in Meta for Developers, with its App ID and
///   Client Token placed in each app's native config (`strings.xml` /
///   `Info.plist`) - `flutter_facebook_auth`'s own setup guide covers this.
///
/// None of that exists yet for this project. Until it does, every method
/// below returns null having surfaced the provider's *real* rejection (a
/// `DEVELOPER_ERROR` from Google, for instance) rather than pretending to
/// succeed - a login screen is the one place a fake success is worse than an
/// honest failure.
class SocialAuthService {
  SocialAuthService._();

  static final _googleSignIn = GoogleSignIn(scopes: const ['email']);

  static Future<SocialCredential?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // user cancelled - not an error
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) return null;
    return SocialCredential(provider: 'google', token: idToken, fullName: account.displayName);
  }

  static Future<SocialCredential?> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    // Only present on the very first authorisation - never available again
    // after, which is why the backend accepts and stores it from the client
    // rather than trying to re-fetch it on a later sign-in.
    final nameParts = [credential.givenName, credential.familyName].whereType<String>();
    final fullName = nameParts.isEmpty ? null : nameParts.join(' ');
    return SocialCredential(provider: 'apple', token: credential.identityToken ?? '', fullName: fullName);
  }

  static Future<SocialCredential?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(permissions: const ['email', 'public_profile']);
    if (result.status != LoginStatus.success) return null; // cancelled or denied
    final token = result.accessToken?.tokenString;
    if (token == null) return null;
    final profile = await FacebookAuth.instance.getUserData(fields: 'name,email');
    return SocialCredential(provider: 'facebook', token: token, fullName: profile['name'] as String?);
  }
}
