import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/auth/auth_hero_layout.dart';
import 'package:staynaija_shared/auth/demo_logins_hint.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/auth/forgot_password_screen.dart';

/// A gradient hero up top, sign-in options docked to the bottom - the
/// wordmark gets to breathe instead of sharing space with a form, and the
/// buttons sit exactly where a thumb already is on a phone held one-handed.
///
/// Email and password only: host accounts are created by the iStay team, so
/// social sign-in has nothing to offer here.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Demo credentials are only ever prefilled when the backend says so (dev /
    // staging) - never in production, where they would just confuse a real host.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillDemo(ref.read(showDemoLoginsProvider)));
  }

  void _prefillDemo(bool show) {
    if (show && _emailController.text.isEmpty && _passwordController.text.isEmpty) {
      _emailController.text = 'host@staynaija.demo';
      _passwordController.text = 'password123';
    }
  }

  Future<void> _requestAccess(AppConfig config) async {
    const message = 'Hi iStay, I would like to list my property as a host.';
    final whatsapp = config.supportWhatsapp;
    final uri = whatsapp != null
        ? Uri.parse('https://wa.me/$whatsapp?text=${Uri.encodeComponent(message)}')
        : Uri(scheme: 'mailto', path: config.supportEmail, queryParameters: {'subject': 'Host access request', 'body': message});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the app to contact us.')));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).login(_emailController.text.trim(), _passwordController.text);
    if (success && mounted && await _requireHost() && mounted) context.go('/');
  }

  /// Host accounts are onboarded manually by the iStay team, so a valid
  /// login that isn't a host (e.g. a guest account) must not get into this app.
  Future<bool> _requireHost() async {
    final user = ref.read(authProvider).user;
    if (user?.isHost == true || user?.isAdmin == true) return true;
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This account is not a host account. Host accounts are set up by the iStay team.')),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    ref.listen<bool>(showDemoLoginsProvider, (_, show) => _prefillDemo(show));

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        children: [
          const Expanded(
            child: AuthHero(logoAsset: 'assets/brand/logo.png', eyebrow: 'Host', subtitle: 'List your property and manage bookings'),
          ),
          AuthSignInPanel(
            error: authState.error,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _emailForm(authState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailForm(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _emailController.text.trim())),
              ),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 8),
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
          const Center(
            child: Text(
              'Host accounts are created by an iStay admin after verification.\nWant to list your property? Contact support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
            ),
          ),
          Consumer(builder: (context, ref, _) {
            final config = ref.watch(appConfigProvider).valueOrNull;
            if (config == null || !config.hasSupportContact) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _requestAccess(config),
                  icon: Icon(LucideIcons.messageSquare, size: 18),
                  label: const Text('Request host access'),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          const DemoLoginsHint(),
        ],
      ),
    );
  }
}
