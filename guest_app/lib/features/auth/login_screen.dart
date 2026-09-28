import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/auth/auth_hero_layout.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/auth/social_auth_service.dart';
import 'package:staynaija_shared/auth/social_sign_in_buttons.dart';

/// A gradient hero up top, sign-in options docked to the bottom - the
/// wordmark gets to breathe instead of sharing space with a form, and the
/// buttons sit exactly where a thumb already is on a phone held one-handed.
///
/// Leads with Google/Apple/Facebook rather than a form: most people opening
/// this for the first time have one of those accounts open on the phone
/// already, and typing an email/password is the slower path for them, not
/// the default one. The form only appears once someone actually asks for it
/// - see [_showEmailForm].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'guest@staynaija.demo');
  final _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;
  bool _showEmailForm = false;

  /// Which provider is mid-sign-in, distinct from the shared `authState`'s
  /// own loading flag: the social SDK step (opening a browser tab, an
  /// account chooser) happens *before* `authProvider` ever starts its own
  /// request, and only that one button should show a spinner during it.
  String? _socialLoadingProvider;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).login(_emailController.text.trim(), _passwordController.text);
    if (success && mounted) context.go('/');
  }

  Future<void> _continueWith(String provider, Future<SocialCredential?> Function() signIn) async {
    setState(() => _socialLoadingProvider = provider);
    try {
      final credential = await signIn();
      if (credential == null) return; // cancelled - not an error worth surfacing
      final success = await ref.read(authProvider.notifier).socialLogin(
            provider: credential.provider,
            token: credential.token,
            fullName: credential.fullName,
            isHost: false,
          );
      if (success && mounted) context.go('/');
    } catch (e) {
      // The SDK step itself can throw before a token ever reaches our own
      // backend call - most notably Apple's sign-in, which has no native
      // credential provider on Android and throws rather than returning one.
      // Surfaced honestly rather than left as an unhandled async error.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sign in with ${_providerName(provider)}: ${_shortError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _socialLoadingProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        children: [
          const Expanded(child: AuthHero(subtitle: 'Find trusted short lets across Nigeria')),
          AuthSignInPanel(
            error: authState.error,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showEmailForm ? _emailForm(authState) : _providerChoice(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerChoice() {
    return Column(
      key: const ValueKey('providers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SocialSignInButtons(
          loadingProvider: _socialLoadingProvider,
          googleLogoAsset: 'assets/google_logo.png',
          facebookLogoAsset: 'assets/facebook_logo.png',
          onGoogle: () => _continueWith('google', SocialAuthService.signInWithGoogle),
          onApple: () => _continueWith('apple', SocialAuthService.signInWithApple),
          onFacebook: () => _continueWith('facebook', SocialAuthService.signInWithFacebook),
        ),
        const SizedBox(height: 18),
        const AuthOrDivider(),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showEmailForm = true),
            icon: Icon(LucideIcons.mail, size: 18),
            label: const Text('Continue with email'),
          ),
        ),
      ],
    );
  }

  Widget _emailForm(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _showEmailForm = false),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            icon: Icon(LucideIcons.chevronLeft, size: 16),
            label: const Text('Other ways to sign in'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
            validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => (value == null || value.length < 6) ? 'Minimum 6 characters' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _submit,
              child: authState.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Log in'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.push('/register'),
              child: const Text("Don't have an account? Sign up"),
            ),
          ),
          const SizedBox(height: 20),
          const _DemoHint(),
        ],
      ),
    );
  }
}

String _providerName(String provider) => switch (provider) {
      'google' => 'Google',
      'apple' => 'Apple',
      'facebook' => 'Facebook',
      _ => provider,
    };

/// A raw exception's `toString()` is often a whole stack of nested error
/// types (Apple's especially: `SignInWithAppleAuthorizationException(...)`),
/// which reads as noise in a one-line SnackBar. Takes just the first
/// sentence-like chunk, which for every provider's real errors so far is the
/// human-readable part.
String _shortError(Object error) {
  final text = error.toString().replaceFirst(RegExp(r'^[A-Za-z.]*Exception:?\s*'), '');
  final cut = text.indexOf(RegExp(r'[.\n]'));
  return (cut > 0 ? text.substring(0, cut) : text).trim();
}

class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: const Text(
        'Demo logins (after running seed.py):\n'
        'guest@staynaija.demo / host@staynaija.demo\n'
        'password: password123',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}
