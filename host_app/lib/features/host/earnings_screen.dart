import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/models/booking.dart';
import 'package:staynaija_host/features/host/host_dashboard_screen.dart';

/// Payout history, derived from the host's own bookings rather than a separate
/// endpoint - every figure a host needs (payout, commission, release date) is
/// already computed server-side and carried on the booking.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(hostBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Earnings')),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(hostBookingsProvider);
          await ref.read(hostBookingsProvider.future);
        },
        child: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load earnings.\n${apiErrorMessage(e)}'))],
          ),
          data: (bookings) {
            final earning = [
              for (final b in bookings)
                if (b.status == BookingStatus.confirmed || b.status == BookingStatus.completed) b,
            ]..sort((a, b) => b.checkIn.compareTo(a.checkIn));

            if (earning.isEmpty) return const _EmptyEarnings();

            final now = DateTime.now();
            final released = earning
                .where((b) => !(b.payoutReleaseAt?.isAfter(now) ?? false))
                .fold<double>(0, (sum, b) => sum + b.hostPayoutAmount);
            final held = earning
                .where((b) => b.payoutReleaseAt?.isAfter(now) ?? false)
                .fold<double>(0, (sum, b) => sum + b.hostPayoutAmount);
            final commission = earning.fold<double>(0, (sum, b) => sum + b.platformFee);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                SoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        icon: LucideIcons.banknote,
                        label: 'Paid out to you',
                        value: formatNaira(released),
                        emphasis: true,
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),
                      _SummaryRow(
                        icon: LucideIcons.clock,
                        label: 'Held in escrow',
                        value: formatNaira(held),
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(
                        icon: LucideIcons.receipt,
                        label: 'StayNaija commission (3.5%)',
                        value: formatNaira(commission),
                        muted: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // States the escrow rule plainly - the most common host question
                // is why money isn't in their account yet.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Guest payments are held for 24 hours after check-in, then released to '
                          'your payout account. This protects both sides if a stay goes wrong.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Payout history'),
                for (final booking in earning) _EarningTile(booking: booking),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasis;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: muted ? AppColors.textSecondary : AppColors.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.5, color: muted ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasis ? 20 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: emphasis ? -0.5 : 0,
            color: muted ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EarningTile extends StatelessWidget {
  const _EarningTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    final isHeld = booking.payoutReleaseAt?.isAfter(DateTime.now()) ?? false;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isHeld ? Colors.orange : AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isHeld ? LucideIcons.clock : LucideIcons.check,
              size: 17,
              color: isHeld ? Colors.orange.shade800 : AppColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dateFormat.format(booking.checkIn)} stay',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  isHeld && booking.payoutReleaseAt != null
                      ? 'Releases ${dateFormat.format(booking.payoutReleaseAt!)}'
                      : 'Released',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            formatNaira(booking.hostPayoutAmount),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}

class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 90, 32, 0),
          child: Column(
            children: [
              Icon(LucideIcons.banknote, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No earnings yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Once a guest books and pays for one of your places, the payout will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
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
