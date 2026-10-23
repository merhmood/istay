import 'dart:io';

import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija/core/router/app_drawer.dart';
import 'package:staynaija/core/widgets/sign_in_prompt.dart';
import 'package:staynaija/features/auth/otp_verify_screen.dart';
import 'package:staynaija_shared/users/user_repository.dart';
import 'package:staynaija_shared/models/user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (isSignedOut(ref) || user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(leading: const DrawerMenuButton(), title: const Text('Profile')),
        body: const SignInPrompt(
          icon: LucideIcons.userRound,
          title: 'Sign in to iStay',
          message: 'Create an account to book stays, save places you like and message hosts directly.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const DrawerMenuButton(), title: const Text('Profile')),
      body: AppRefresh(
        // Re-fetches the account, so verification status updates without a
        // restart once documents have been reviewed.
        onRefresh: () => ref.read(authProvider.notifier).refreshUser(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: _ProfileHeader(user: user),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Verification'),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _VerificationSection(user: user),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Account'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _NavRow(
                  icon: LucideIcons.heart,
                  label: 'Saved',
                  description: 'Listings you have favourited',
                  onTap: () => context.push('/saved'),
                ),
                _NavRow(
                  icon: LucideIcons.creditCard,
                  label: 'Payments',
                  description: 'Your payment history',
                  onTap: () => context.push('/payments'),
                ),
                _NavRow(
                  icon: LucideIcons.shieldCheck,
                  label: 'Escrow',
                  description: 'Money held for upcoming stays',
                  onTap: () => context.push('/escrow'),
                ),
                _NavRow(
                  icon: LucideIcons.circleHelp,
                  label: 'Help & support',
                  description: 'FAQs and how to reach us',
                  onTap: () => context.push('/support'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Hosting'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _NavRow(
              icon: LucideIcons.house,
              label: 'Become a host',
              description: 'List a property using the iStay Host app',
              trailingIcon: LucideIcons.arrowUpRight,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download the iStay Host app to list a property.')),
              ),
            ),
          ),
          const SizedBox(height: 26),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: Icon(LucideIcons.logOut, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isVerified = user.verificationStatus == 'verified';

    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null
              ? Text(
                  _initials(user.fullName),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 22),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (isVerified) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    const Text(
                      'Verified guest',
                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.trailingIcon,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(trailingIcon ?? LucideIcons.chevronRight, size: 17, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _VerificationSection extends ConsumerStatefulWidget {
  const _VerificationSection({required this.user});

  final AppUser user;

  @override
  ConsumerState<_VerificationSection> createState() => _VerificationSectionState();
}

class _VerificationSectionState extends ConsumerState<_VerificationSection> {
  bool _isUploading = false;
  String? _error;

  Future<void> _uploadDocuments() async {
    final picker = ImagePicker();
    final idDoc = await picker.pickImage(source: ImageSource.gallery);
    if (idDoc == null) return;
    final selfie = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (selfie == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      await UserRepository().uploadVerificationDocuments(idDocument: File(idDoc.path), selfie: File(selfie.path));
      await ref.read(authProvider.notifier).refreshUser();
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusRow(
          'Phone number',
          user.phoneVerified,
          action: user.phoneNumber == null
              ? null
              : () async {
                  final phoneNumber = user.phoneNumber!;
                  final verified = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OtpVerifyScreen(phoneNumber: phoneNumber)),
                  );
                  if (verified == true) await ref.read(authProvider.notifier).refreshUser();
                },
        ),
        _statusRow('Email address', user.emailVerified),
        _statusRow(
          'ID & selfie',
          user.verificationStatus == 'verified',
          subtitle: user.verificationStatus == 'pending' ? 'Pending manual review' : null,
          action: user.verificationStatus == 'unverified' || user.verificationStatus == 'rejected'
              ? _uploadDocuments
              : null,
        ),
        if (_isUploading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
          ),
      ],
    );
  }

  Widget _statusRow(String label, bool verified, {String? subtitle, VoidCallback? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            verified ? LucideIcons.circleCheck : LucideIcons.circleDashed,
            size: 19,
            color: verified ? AppColors.primary : Colors.grey.shade400,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14.5)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          if (verified)
            Text(
              'Verified',
              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
            )
          else if (action != null)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: action,
              child: const Text('Verify', style: TextStyle(fontSize: 13)),
            )
          else
            Text('Not verified', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}
