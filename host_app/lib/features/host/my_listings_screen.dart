import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/widgets/empty_state.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_shared/models/listing.dart';

final myListingsProvider = FutureProvider.autoDispose((ref) => ref.watch(listingRepositoryProvider).myListings());

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/listings/new');
          ref.invalidate(myListingsProvider);
        },
        icon: Icon(LucideIcons.plus),
        label: const Text('New listing'),
      ),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(myListingsProvider);
          // Await the refetch so the indicator stays until new data
          // lands, instead of snapping away the moment it is asked for.
          await ref.read(myListingsProvider.future);
        },
        child: listingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(apiErrorMessage(e)))]),
          data: (listings) {
            if (listings.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: LucideIcons.house,
                  title: 'No listings yet',
                  message: 'Add your first property and it will appear here, ready for guests to find and book.',
                  actionLabel: 'Create a listing',
                  actionIcon: LucideIcons.plus,
                  onAction: () async {
                    await context.push('/listings/new');
                    ref.invalidate(myListingsProvider);
                  },
                ),
              );
            }
            return ListView.separated(
              // Bottom inset clears the extended FAB, which otherwise sits over
              // the last card's Edit/Calendar row and blocks both buttons.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ListingTile(listing: listings[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ListingTile extends ConsumerWidget {
  const _ListingTile({required this.listing});

  final Listing listing;

  Future<void> _togglePublished(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(listingRepositoryProvider).setPublished(listing.id, !listing.isPublished);
      ref.invalidate(myListingsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('"${listing.title}" and its photos will be permanently removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(listingRepositoryProvider).delete(listing.id);
      ref.invalidate(myListingsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final published = listing.isPublished;

    return SoftCard(
      // Bottom inset is small because the action buttons below the divider
      // carry their own vertical padding; a full 12 here made the gap under
      // the divider visibly larger than the gap above it.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      onTap: () => context.push('/listings/${listing.id}/edit', extra: listing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The host's own photo, not a generic icon - they recognise their
              // properties by sight far faster than by title.
              AppImage(
                url: listing.photos.isNotEmpty ? listing.photos.first.url : null,
                width: 76,
                height: 76,
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
                          decoration: BoxDecoration(
                            color: published ? AppColors.primary : Colors.orange.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          published ? 'PUBLISHED' : 'UNPUBLISHED',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: published ? AppColors.primary : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.city} · ${listing.bedrooms} bed · up to ${listing.maxGuests}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(formatNaira(listing.displayRate), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(' / ${listing.displayUnitLabel}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // No gap here on purpose: the buttons' own 40px height centres their
          // labels, which supplies the matching space below the divider.
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => context.push('/listings/${listing.id}/edit', extra: listing),
                  icon: Icon(LucideIcons.pencil, size: 15),
                  label: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.grey.shade200),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => context.push('/listings/${listing.id}/calendar'),
                  icon: Icon(LucideIcons.calendarDays, size: 15),
                  label: const Text('Calendar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.grey.shade200),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => _togglePublished(context, ref),
                  icon: Icon(published ? LucideIcons.eyeOff : LucideIcons.eye, size: 15),
                  label: Text(published ? 'Unpublish' : 'Publish',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.grey.shade200),
              IconButton(
                tooltip: 'Delete listing',
                onPressed: () => _delete(context, ref),
                icon: Icon(LucideIcons.trash2, size: 16, color: Colors.red.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
