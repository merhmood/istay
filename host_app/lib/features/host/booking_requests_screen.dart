import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/widgets/empty_state.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/bookings/booking_repository.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_shared/models/booking.dart';
import 'package:staynaija_host/features/host/host_dashboard_screen.dart';

/// Declared once at top level rather than inside a widget's build: creating a
/// provider per build leaks a new one on every rebuild and refetches endlessly.
final _requestListingProvider = FutureProvider.autoDispose.family(
  (ref, String listingId) => ref.watch(listingRepositoryProvider).getById(listingId),
);

class BookingRequestsScreen extends ConsumerWidget {
  const BookingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(hostBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Booking requests')),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(hostBookingsProvider);
          // Await the refetch so the indicator stays until new data
          // lands, instead of snapping away the moment it is asked for.
          await ref.read(hostBookingsProvider.future);
        },
        child: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(apiErrorMessage(e)))]),
          data: (bookings) {
            final pending = bookings.where((b) => b.status == BookingStatus.pendingHostApproval).toList();
            if (pending.isEmpty) {
              return const ScrollableEmptyState(
                child: EmptyState(
                  icon: LucideIcons.inbox,
                  title: 'No requests waiting',
                  message: 'When a guest asks to book one of your places, it will show up here for you to accept or decline.',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _RequestTile(booking: pending[index]),
            );
          },
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(_requestListingProvider(booking.listingId));

    final listing = listingAsync.valueOrNull;
    final nights = booking.checkOut.difference(booking.checkIn).inDays;
    final dateFormat = DateFormat('d MMM');

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: listing != null && listing.photos.isNotEmpty ? listing.photos.first.url : null,
                width: 64,
                height: 64,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: Colors.orange.shade700, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AWAITING YOUR REPLY',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      listing?.title ?? (listingAsync.hasError ? 'Listing unavailable' : 'Loading...'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // The three facts a host decides on, given equal prominence.
          Row(
            children: [
              Expanded(
                child: _Fact(
                  label: 'DATES',
                  value: '${dateFormat.format(booking.checkIn)} - ${dateFormat.format(booking.checkOut)}',
                ),
              ),
              Expanded(child: _Fact(label: 'NIGHTS', value: '$nights')),
              Expanded(
                child: _Fact(
                  label: 'GUESTS',
                  value: '${booking.numGuests}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('Your payout', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const Spacer(),
                Text(
                  formatNaira(booking.hostPayoutAmount),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: () => _respond(ref, BookingStatus.declined),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    // Overrides the theme's full-width minimumSize; a Row
                    // measures non-flex children with unbounded width.
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _respond(ref, BookingStatus.confirmed),
                    child: const Text('Accept booking', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(WidgetRef ref, BookingStatus status) async {
    await ref.read(bookingRepositoryProvider).updateStatus(booking.id, status);
    ref.invalidate(hostBookingsProvider);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
