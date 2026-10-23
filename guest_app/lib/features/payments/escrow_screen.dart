import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija/features/payments/payments_provider.dart';
import 'package:staynaija/features/payments/payments_screen.dart';

/// The guest-facing view of the escrow hold: money already paid that the host
/// cannot draw down until 24h after check-in.
class EscrowScreen extends ConsumerWidget {
  const EscrowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Escrow')),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(paymentHistoryProvider);
          // Await the refetch so the indicator stays until new data
          // lands, instead of snapping away the moment it is asked for.
          await ref.read(paymentHistoryProvider.future);
        },
        child: paymentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load escrow.\n${apiErrorMessage(e)}'))],
          ),
          data: (payments) {
            final held = [for (final payment in payments) if (payment.inEscrow) payment];
            final totalHeld = held.fold<double>(0, (sum, payment) => sum + payment.amount);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Protected by iStay',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(formatNaira(totalHeld), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        held.length == 1 ? 'held across 1 booking' : 'held across ${held.length} bookings',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Text(
                    'Your payment is held securely and only released to the host 24 hours after you check in. '
                    'If the place is not as described, raise it with support before then.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                if (held.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('Nothing in escrow right now.', style: TextStyle(color: AppColors.textSecondary))),
                  )
                else
                  for (final payment in held) ...[
                    PaymentTile(payment: payment, showEscrowNote: true),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}
