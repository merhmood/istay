import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/bookings/payment_repository.dart';
import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija/features/payments/payments_provider.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
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
            children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load payments.\n${apiErrorMessage(e)}'))],
          ),
          data: (payments) {
            if (payments.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No payments yet.', style: TextStyle(color: AppColors.textSecondary))),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => PaymentTile(payment: payments[index]),
            );
          },
        ),
      ),
    );
  }
}

/// Shared by the payments and escrow screens so a held payment looks the same
/// in both places.
class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, this.showEscrowNote = false});

  final PaymentHistoryEntry payment;
  final bool showEscrowNote;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    final (statusColor, statusLabel) = _status(payment);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  payment.listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Text(formatNaira(payment.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${payment.listingCity} · ${dateFormat.format(payment.checkIn)} - ${dateFormat.format(payment.checkOut)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(dateFormat.format(payment.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          if (showEscrowNote && payment.payoutReleaseAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Released to host ${dateFormat.format(payment.payoutReleaseAt!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text('Ref ${payment.reference}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  (Color, String) _status(PaymentHistoryEntry payment) {
    if (payment.inEscrow) return (AppColors.primary, 'Held in escrow');
    return switch (payment.status) {
      'success' => (AppColors.primary, 'Paid'),
      'failed' => (AppColors.error, 'Failed'),
      _ => (AppColors.accent, 'Pending'),
    };
  }
}
