import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/bookings/payment_repository.dart';

/// Backs both the payments history and escrow screens - they are two views of
/// the same `/payments/mine` response, so they share one request.
final paymentHistoryProvider = FutureProvider.autoDispose<List<PaymentHistoryEntry>>(
  (ref) => ref.watch(paymentRepositoryProvider).myPayments(),
);
