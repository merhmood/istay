import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/bookings/booking_repository.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_host/features/host/my_listings_screen.dart' show myListingsProvider;
import 'package:staynaija_shared/models/booking.dart';

final hostBookingsProvider = FutureProvider.autoDispose((ref) => ref.watch(bookingRepositoryProvider).myBookings(asHost: true));

/// Shared with the full Analytics screen (see analytics_screen.dart), which
/// reuses this exact provider rather than firing a second request for the
/// same numbers - the same pattern `hostBookingsProvider` above already
/// established for earnings/requests.
final hostAnalyticsProvider = FutureProvider.autoDispose((ref) => ref.watch(listingRepositoryProvider).getAnalytics());

class HostDashboardScreen extends ConsumerWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(hostBookingsProvider);
    final firstName = (ref.watch(authProvider).user?.fullName ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(hostBookingsProvider);
          // Await the refetch so the indicator stays until new data lands,
          // instead of snapping away the moment it is asked for.
          await ref.read(hostBookingsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18, top: 8, left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName.isEmpty ? 'Welcome back' : 'Hi $firstName',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Here's how your places are doing",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ),
            const _GettingStartedCard(),
            bookingsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SoftCard(
                child: Text('Could not load your dashboard.\n${apiErrorMessage(e)}'),
              ),
              data: (bookings) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EarningsHero(bookings: bookings),
                  const SizedBox(height: 14),
                  _StatsRow(bookings: bookings),
                  const SizedBox(height: 14),
                  const _PerformanceSummary(),
                  const SizedBox(height: 26),
                  const _SectionLabel('Upcoming stays'),
                  _UpcomingList(bookings: bookings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The number a host opens this app to see, given the weight to match.
class _EarningsHero extends StatelessWidget {
  const _EarningsHero({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final earned = bookings
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
        .fold<double>(0, (sum, b) => sum + b.hostPayoutAmount);
    final pending = bookings
        .where((b) => b.status == BookingStatus.confirmed && (b.payoutReleaseAt?.isAfter(DateTime.now()) ?? false))
        .fold<double>(0, (sum, b) => sum + b.hostPayoutAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        // Subtle vertical gradient rather than flat fill, so the hero reads as
        // the one elevated surface on the screen.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wallet, size: 15, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 7),
              Text(
                'TOTAL EARNED',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatNaira(earned),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8),
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 14, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 7),
              Text(
                '${formatNaira(pending)} held in escrow',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// At-a-glance counts, so the host can see activity without reading the lists.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final pending = bookings.where((b) => b.status == BookingStatus.pendingHostApproval).length;
    final confirmed = bookings.where((b) => b.status == BookingStatus.confirmed).length;
    final completed = bookings.where((b) => b.status == BookingStatus.completed).length;

    return Row(
      children: [
        Expanded(child: _StatTile(value: '$pending', label: 'Requests', highlight: pending > 0)),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(value: '$confirmed', label: 'Confirmed')),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(value: '$completed', label: 'Completed')),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.highlight = false});

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              // Anything waiting on the host is worth pulling the eye to.
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// The two or three numbers that answer "is anyone actually looking?" -
/// deliberately just that, not the full breakdown. The Analytics screen
/// behind it has the per-listing detail and the trend chart; this card
/// exists to be read in one glance rather than to duplicate that screen.
class _PerformanceSummary extends ConsumerWidget {
  const _PerformanceSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(hostAnalyticsProvider);

    return analyticsAsync.when(
      // Quiet on loading/error - this card is a bonus on top of the numbers
      // above it, not something worth a spinner or an error banner of its own.
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (analytics) {
        // Nothing to summarise yet - the full screen's own empty state
        // explains why, so this card just doesn't appear rather than
        // showing a row of zeroes.
        if (analytics.listings.isEmpty) return const SizedBox.shrink();

        return SoftCard(
          padding: const EdgeInsets.all(16),
          onTap: () => context.push('/analytics'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.barChart3, size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  const Text(
                    'PERFORMANCE',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(LucideIcons.chevronRight, size: 15, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _PerformanceFigure(value: '${analytics.totalViews}', label: 'Views'),
                  _performanceDivider(),
                  _PerformanceFigure(value: '${analytics.totalBookings}', label: 'Bookings'),
                  _performanceDivider(),
                  _PerformanceFigure(
                    value: analytics.conversionRate == null
                        ? '—'
                        : '${(analytics.conversionRate! * 100).toStringAsFixed(0)}%',
                    label: 'Convert',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _performanceDivider() => Container(width: 1, height: 30, color: AppColors.background);
}

class _PerformanceFigure extends StatelessWidget {
  const _PerformanceFigure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
        ],
      ),
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

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final upcoming = [
      for (final b in bookings)
        if (b.status == BookingStatus.confirmed && b.checkOut.isAfter(DateTime.now())) b,
    ]..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    if (upcoming.isEmpty) {
      return SoftCard(
        child: Row(
          children: [
            Icon(LucideIcons.calendarDays, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No upcoming stays yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [for (final booking in upcoming) _BookingSummaryTile(booking: booking)],
    );
  }
}

class _BookingSummaryTile extends StatelessWidget {
  const _BookingSummaryTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM');
    final nights = booking.checkOut.difference(booking.checkIn).inDays;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Compact date block, so a glance down the list reads as a calendar.
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(booking.checkIn).toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5),
                ),
                Text(
                  '${booking.checkIn.day}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dateFormat.format(booking.checkIn)} - ${DateFormat('d MMM').format(booking.checkOut)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  '$nights ${nights == 1 ? 'night' : 'nights'} · ${booking.numGuests} guest${booking.numGuests == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

/// First-run checklist for a new host: what is still missing before they can
/// take a booking and get paid. Disappears once everything is done.
class _GettingStartedCard extends ConsumerWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final listings = ref.watch(myListingsProvider).valueOrNull;
    if (user == null || listings == null) return const SizedBox.shrink();

    final hasListing = listings.isNotEmpty;
    final hasPayout = user.hasPayoutAccount;
    if (hasListing && hasPayout) return const SizedBox.shrink();

    Widget step(bool done, String label, String route) => InkWell(
          onTap: done ? null : () => route == '/profile' ? context.go(route) : context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Icon(
                  done ? LucideIcons.circleCheck : LucideIcons.circleDashed,
                  size: 20,
                  color: done ? AppColors.primary : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (!done) Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Get started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text(
              'Two quick steps and you are ready for bookings.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            step(hasListing, 'Create your first listing', '/listings/new'),
            const Divider(height: 1),
            step(hasPayout, 'Add your payout details', '/profile'),
          ],
        ),
      ),
    );
  }
}
