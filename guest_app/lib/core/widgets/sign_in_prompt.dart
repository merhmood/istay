import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

/// True when the visitor is browsing without an account.
bool isSignedOut(WidgetRef ref) => ref.watch(authProvider).status != AuthStatus.authenticated;

/// Shown in place of a tab that can't mean anything without an account, rather
/// than redirecting - the bottom nav should never dead-end.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
          child: Column(
            children: [
              Icon(icon, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.55),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for gated *actions* taken while browsing - saving a listing,
/// booking, messaging a host. Keeps the visitor where they were instead of
/// throwing them to a full-screen login.
Future<void> promptSignIn(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Icon(LucideIcons.lockKeyhole, size: 26, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.55),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/login');
                },
                child: const Text('Sign in'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/register');
                },
                child: const Text('Create an account'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
