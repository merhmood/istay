import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/api_error_view.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija/core/router/app_drawer.dart';
import 'package:staynaija/features/discovery/discovery_provider.dart';
import 'package:staynaija/features/discovery/widgets/recommended_listing_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(recommendedListingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text('StayNaija', style: brandTextStyle(fontSize: 26)),
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.heart, style: HeroIconStyle.outline),
            tooltip: 'Saved',
            onPressed: () => context.push('/saved'),
          ),
        ],
      ),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(recommendedListingsProvider);
          // Await the refetch so the indicator stays until new data
          // lands, instead of snapping away the moment it is asked for.
          await ref.read(recommendedListingsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Places you may like',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // "Past stays" undersold it and was wrong for the many guests who
            // have not booked yet: the feed is built from everything they have
            // browsed, mapped and asked directions to, not just bookings.
            const Text(
              'Picked from the places you browse and search',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            recommendedAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Center(
                child: ApiErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(recommendedListingsProvider),
                ),
              ),
              data: (listings) {
                if (listings.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No recommendations yet - try exploring listings.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final listing in listings) ...[
                      RecommendedListingCard(
                        listing: listing,
                        onTap: () => context.push('/listing/${listing.id}'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
