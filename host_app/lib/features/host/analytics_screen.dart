import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_host/features/host/host_dashboard_screen.dart';

/// How many people are actually looking, and how many of them book.
///
/// Built on the same `listing_interactions` rows the recommendation model
/// reads - a host has never had a way to see them before this screen, even
/// though the data was already being collected every time a guest opened a
/// listing, tapped its map pin, or asked for directions to it.
///
/// Kept to three things - the headline numbers, a trend, and the top few
/// listings - rather than a full breakdown of every listing and every signal.
/// A host with twenty listings does not want to scroll a wall of near-
/// identical cards to find the two that actually matter.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(hostAnalyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Analytics')),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(hostAnalyticsProvider);
          await ref.read(hostAnalyticsProvider.future);
        },
        child: analyticsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('Could not load analytics.\n${apiErrorMessage(e)}')),
            ],
          ),
          data: (analytics) {
            if (analytics.listings.isEmpty) return const _EmptyAnalytics();

            // The other 5 listings' worth of detail is a scroll a host has to
            // want, not one shown by default - "what's working" is usually
            // answered by the busiest handful, not the whole catalogue.
            const topCount = 5;
            final topListings = analytics.listings.take(topCount).toList();
            final remaining = analytics.listings.length - topListings.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _SummaryStrip(analytics: analytics),
                const SizedBox(height: 22),
                const _SectionLabel('Bookings, last 6 months'),
                SoftCard(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                  child: _TrendChart(points: analytics.monthlyTrend),
                ),
                const SizedBox(height: 22),
                const _SectionLabel('Top listings'),
                const Text(
                  "Ranked by views, so you can see what's actually getting looked at.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                for (final listing in topListings)
                  _ListingPerformanceTile(listing: listing, maxViews: topListings.first.views),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      '+ $remaining more listing${remaining == 1 ? '' : 's'} not shown',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The four headline numbers in one card, laid out in a single row rather
/// than four separate cards - the same information, a quarter of the height.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.analytics});

  final HostAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          _Figure(icon: LucideIcons.eye, value: '${analytics.totalViews}', label: 'Views'),
          _stripDivider(),
          _Figure(icon: LucideIcons.navigation, value: '${analytics.totalDirections}', label: 'Directions'),
          _stripDivider(),
          _Figure(
            icon: LucideIcons.calendarCheck,
            value: '${analytics.totalBookings}',
            label: 'Bookings',
            highlight: true,
          ),
          _stripDivider(),
          _Figure(
            icon: LucideIcons.percent,
            value: analytics.conversionRate == null ? '—' : '${(analytics.conversionRate! * 100).toStringAsFixed(0)}%',
            label: 'Convert',
          ),
        ],
      ),
    );
  }

  Widget _stripDivider() => Container(width: 1, height: 34, color: AppColors.background);
}

class _Figure extends StatelessWidget {
  const _Figure({required this.icon, required this.value, required this.label, this.highlight = false});

  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.textPrimary;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 15, color: highlight ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5), maxLines: 1),
        ],
      ),
    );
  }
}

/// A plain bar chart, hand-drawn rather than pulled in from a charting
/// package - six bars and a couple of axis labels is well within what a
/// `CustomPainter` does cleanly, and it keeps this screen's only new
/// dependency at zero.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<MonthlyTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxBookings = points.map((p) => p.bookings).fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in points)
                Expanded(
                  child: _TrendBar(
                    // A floor so a month with 1 booking is still visible next
                    // to a month with 0, rather than reading as the same bar.
                    heightFraction: maxBookings == 0 ? 0 : (0.08 + 0.92 * point.bookings / maxBookings),
                    isZero: point.bookings == 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final point in points)
              Expanded(
                child: Text(
                  point.shortLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.heightFraction, required this.isZero});

  final double heightFraction;
  final bool isZero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: FractionallySizedBox(
        heightFactor: heightFraction.clamp(0.0, 1.0),
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isZero ? AppColors.textSecondary.withValues(alpha: 0.15) : AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
      ),
    );
  }
}

class _ListingPerformanceTile extends StatelessWidget {
  const _ListingPerformanceTile({required this.listing, required this.maxViews});

  final ListingAnalytics listing;

  /// The busiest listing's view count, so every bar is relative to it - an
  /// absolute scale would make every listing except the top one look empty.
  final int maxViews;

  @override
  Widget build(BuildContext context) {
    final fraction = maxViews == 0 ? 0.0 : listing.views / maxViews;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric(LucideIcons.eye, '${listing.views}', 'views'),
              const SizedBox(width: 18),
              _metric(LucideIcons.navigation, '${listing.directions}', 'directions'),
              const Spacer(),
              _metric(LucideIcons.calendarCheck, '${listing.bookings}', 'booked', highlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label, {bool highlight = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: highlight ? AppColors.primary : AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
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
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
      );
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 90, 32, 0),
          child: Column(
            children: [
              Icon(LucideIcons.barChart3, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No listings yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Once you publish a listing, views and bookings will show up here.',
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
