import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/widgets/empty_state.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/favorites/favorite_repository.dart';
import 'package:staynaija/features/discovery/widgets/listing_card.dart';

final savedListingsProvider = FutureProvider.autoDispose((ref) => ref.watch(favoriteRepositoryProvider).list());

class SavedListingsScreen extends ConsumerWidget {
  const SavedListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedListingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(savedListingsProvider);
          // Await the refetch so the indicator stays until new data
          // lands, instead of snapping away the moment it is asked for.
          await ref.read(savedListingsProvider.future);
        },
        child: savedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load saved listings.\n${apiErrorMessage(e)}'))]),
          data: (listings) {
            if (listings.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: LucideIcons.heart,
                  title: 'Nothing saved yet',
                  message: 'Tap the heart on any listing and it will be kept here, so you can compare places before you book.',
                  actionLabel: 'Find places',
                  actionIcon: LucideIcons.search,
                  onAction: () => context.go('/explore'),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.58,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return ListingCard(listing: listing, onTap: () => context.push('/listing/${listing.id}'));
              },
            );
          },
        ),
      ),
    );
  }
}
