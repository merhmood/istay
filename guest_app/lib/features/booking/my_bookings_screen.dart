import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/bookings/booking_repository.dart';
import 'package:staynaija/core/widgets/sign_in_prompt.dart';
import 'package:staynaija/features/discovery/discovery_provider.dart';
import 'package:staynaija/features/profile/review_dialog.dart';
import 'package:staynaija_shared/models/booking.dart';
import 'package:staynaija_shared/models/listing.dart';

final myBookingsProvider = FutureProvider.autoDispose((ref) => ref.watch(bookingRepositoryProvider).myBookings());

/// Declared once at top level rather than inside a widget's build: creating a
/// provider per build leaks a new one on every rebuild and refetches endlessly.
final _bookingListingProvider = FutureProvider.autoDispose.family<Listing, String>(
  (ref, listingId) => ref.watch(listingRepositoryProvider).getById(listingId),
);

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSignedOut(ref)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('My trips')),
        body: const SignInPrompt(
          icon: LucideIcons.luggage,
          title: 'Sign in to see your trips',
          message: 'Your bookings, payment status and check-in dates all live here once you have an account.',
        ),
      );
    }

    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      // Cards need a tinted backdrop to read as raised; on white they vanish.
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My trips')),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(myBookingsProvider);
          // Await the refetch so the indicator stays until new data
          // lands, instead of snapping away the moment it is asked for.
          await ref.read(myBookingsProvider.future);
        },
        child: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('Could not load trips.\n${apiErrorMessage(e)}')),
            ],
          ),
          data: (bookings) {
            if (bookings.isEmpty) return const _EmptyTrips();

            final today = DateTime.now();
            final upcoming = [for (final b in bookings) if (!b.checkOut.isBefore(today) && _isLive(b.status)) b]
              ..sort((a, b) => a.checkIn.compareTo(b.checkIn));
            final past = [for (final b in bookings) if (b.checkOut.isBefore(today) || !_isLive(b.status)) b]
              ..sort((a, b) => b.checkIn.compareTo(a.checkIn));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _SectionLabel('Upcoming'),
                  for (final booking in upcoming) _BookingTile(booking: booking),
                ],
                if (past.isNotEmpty) ...[
                  SizedBox(height: upcoming.isEmpty ? 0 : 20),
                  const _SectionLabel('Past trips'),
                  for (final booking in past) _BookingTile(booking: booking, dimmed: true),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static bool _isLive(BookingStatus status) =>
      status != BookingStatus.cancelled && status != BookingStatus.declined && status != BookingStatus.completed;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6, left: 4),
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

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 90, 32, 0),
          child: Column(
            children: [
              Icon(LucideIcons.luggage, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No trips yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Once you book a stay it will show up here, with your dates and payment status.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => context.go('/explore'),
                icon: Icon(LucideIcons.search, size: 16),
                label: const Text('Find a place to stay'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking, this.dimmed = false});

  final Booking booking;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(_bookingListingProvider(booking.listingId));
    final dateFormat = DateFormat('d MMM');
    final listing = listingAsync.valueOrNull;
    final nights = booking.checkOut.difference(booking.checkIn).inDays;

    return Opacity(
      opacity: dimmed ? 0.78 : 1,
      child: SoftCard(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/listing/${booking.listingId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status sits on its own top line with the nights count opposite,
            // so the title below gets the card's full width instead of being
            // squeezed beside the photo.
            Row(
              children: [
                Expanded(child: _StatusLine(status: booking.status)),
                Text(
                  '$nights ${nights == 1 ? 'night' : 'nights'}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: AppImage(url: listing != null && listing.photos.isNotEmpty ? listing.photos.first.url : null),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing?.title ?? (listingAsync.hasError ? 'Listing unavailable' : 'Loading...'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.25, letterSpacing: -0.2),
                      ),
                      if (listing != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${listing.city} · ${listing.neighborhoodLandmark}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Dates and total get their own baseline row: the two facts a guest
            // actually scans for, no longer buried under the title.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DATES', style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 3),
                      Text(
                        '${dateFormat.format(booking.checkIn)} - ${DateFormat('d MMM').format(booking.checkOut)}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${booking.numGuests} guest${booking.numGuests == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(formatNaira(booking.totalPrice), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -0.3)),
                  ],
                ),
              ],
            ),
            _actions(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref) {
    // The primary action spans the card; secondary actions stay quiet text on
    // a line of their own beneath it. Anything less than full-width read as an
    // afterthought next to the total.
    if (booking.status == BookingStatus.awaitingPayment) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push('/checkout/${booking.id}'),
                // Styled on the Text, not via styleFrom's textStyle: a bare
                // TextStyle there replaces the button's whole text style,
                // dropping the theme's Poppins fontFamily to the platform default.
                child: const Text('Pay now', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
            ),
            _cancelButton(ref),
          ],
        ),
      );
    }

    if (booking.status == BookingStatus.pendingHostApproval) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(alignment: Alignment.centerRight, child: _cancelButton(ref)),
      );
    }

    if (booking.status == BookingStatus.completed) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => showReviewDialog(context, booking.id),
            icon: Icon(LucideIcons.star, size: 14),
            label: const Text('Leave a review', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _cancelButton(WidgetRef ref) => TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () async {
          await ref.read(bookingRepositoryProvider).updateStatus(booking.id, BookingStatus.cancelled);
          ref.invalidate(myBookingsProvider);
        },
        child: const Text('Cancel booking', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      );
}

/// Status as a coloured dot plus label - no chip, matching the rest of the
/// borderless treatment.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BookingStatus.confirmed || BookingStatus.completed => AppColors.primary,
      BookingStatus.declined || BookingStatus.cancelled => AppColors.error,
      _ => Colors.orange.shade700,
    };

    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          status.label.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
      ],
    );
  }
}
