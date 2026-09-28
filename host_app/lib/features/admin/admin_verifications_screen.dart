import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/admin/admin_repository.dart';
import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';

const _tabs = [
  (label: 'Pending', status: 'pending'),
  (label: 'Verified', status: 'verified'),
  (label: 'Rejected', status: 'rejected'),
];

final _verificationsProvider = FutureProvider.autoDispose.family<List<VerificationRequest>, String>(
  (ref, status) => ref.watch(adminRepositoryProvider).listVerifications(status: status),
);

class AdminVerificationsScreen extends StatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  State<AdminVerificationsScreen> createState() => _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: _tabs.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verifications'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [for (final tab in _tabs) Tab(text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [for (final tab in _tabs) _VerificationList(status: tab.status)],
      ),
    );
  }
}

class _VerificationList extends ConsumerWidget {
  const _VerificationList({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_verificationsProvider(status));

    return AppRefresh(
      onRefresh: () async {
        ref.invalidate(_verificationsProvider(status));
        await ref.read(_verificationsProvider(status).future);
      },
      child: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(padding: const EdgeInsets.all(24), child: Text('Could not load requests.\n${apiErrorMessage(e)}')),
          ],
        ),
        data: (requests) {
          if (requests.isEmpty) return _EmptyState(status: status);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              for (final request in requests)
                _VerificationCard(
                  request: request,
                  onReviewed: () => ref.invalidate(_verificationsProvider(status)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 90, 32, 0),
          child: Column(
            children: [
              Icon(LucideIcons.shieldCheck, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No $status requests', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                status == 'pending' ? "You're all caught up." : 'Nothing here yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerificationCard extends ConsumerStatefulWidget {
  const _VerificationCard({required this.request, required this.onReviewed});

  final VerificationRequest request;
  final VoidCallback onReviewed;

  @override
  ConsumerState<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends ConsumerState<_VerificationCard> {
  bool _isSubmitting = false;

  Future<void> _review(bool approve) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminRepositoryProvider).reviewVerification(widget.request.id, approve: approve);
      widget.onReviewed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: ${apiErrorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(request.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  request.isHost ? 'Host' : 'Guest',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DocumentThumb(label: 'ID document', url: request.idDocumentUrl)),
              const SizedBox(width: 10),
              Expanded(child: _DocumentThumb(label: 'Selfie', url: request.selfieUrl)),
            ],
          ),
          const SizedBox(height: 14),
          if (request.verificationStatus == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _review(false),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error.withValues(alpha: 0.4))),
                    icon: Icon(LucideIcons.ban, size: 16),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _review(true),
                    icon: _isSubmitting
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(LucideIcons.check, size: 16, color: Colors.white),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            )
          else
            _StatusPill(status: request.verificationStatus),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isVerified = status == 'verified';
    final color = isVerified ? AppColors.primary : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isVerified ? LucideIcons.checkCircle : LucideIcons.ban, size: 14, color: color),
          const SizedBox(width: 6),
          Text(isVerified ? 'Verified' : 'Rejected', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: url == null ? null : () => _openFullScreen(context, url!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: AppImage(url: url, borderRadius: BorderRadius.circular(10), fallbackIcon: LucideIcons.fileText),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(child: InteractiveViewer(child: AppImage(url: url))),
        ),
      ),
    );
  }
}
