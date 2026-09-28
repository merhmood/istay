import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija/core/widgets/sign_in_prompt.dart';
import 'package:staynaija/features/discovery/favorites_provider.dart';

/// Full-width card for the single-column "Recommended for you" home feed.
class RecommendedListingCard extends ConsumerStatefulWidget {
  const RecommendedListingCard({super.key, required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  ConsumerState<RecommendedListingCard> createState() => _RecommendedListingCardState();
}

class _RecommendedListingCardState extends ConsumerState<RecommendedListingCard> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final hasPower = listing.hasGenerator || listing.hasInverter || listing.has24hrElectricity;
    final hasSecurity = listing.isGatedEstate || listing.hasSecurityGuard || listing.hasCctv;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: listing.photos.isEmpty
                        ? _placeholder()
                        : PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) => setState(() => _page = index),
                            itemCount: listing.photos.length,
                            itemBuilder: (context, index) => AppImage(url: listing.photos[index].url),
                          ),
                  ),
                  if (listing.photos.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < listing.photos.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: i == _page ? 7 : 5,
                              height: i == _page ? 7 : 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: i == _page ? 1 : 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (listing.instantBook)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _pillBadge(icon: LucideIcons.zap, label: 'Instant book'),
                    ),
                  Positioned(top: 12, right: 12, child: _favoriteButton(listing.id)),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: _priceTag(listing),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${listing.city} · ${listing.neighborhoodLandmark}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _infoChip(LucideIcons.bedDouble, '${listing.bedrooms} bed'),
                      _infoChip(LucideIcons.users, 'Up to ${listing.maxGuests}'),
                      if (hasPower) _infoChip(LucideIcons.zap, 'Power'),
                      if (hasSecurity) _infoChip(LucideIcons.shieldCheck, 'Secure'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriteButton(String listingId) {
    final isFavorite = ref.watch(favoritesProvider.select((ids) => ids.contains(listingId)));
    return GestureDetector(
      onTap: () {
        if (isSignedOut(ref)) {
          promptSignIn(
            context,
            title: 'Save this place',
            message: 'Sign in to keep a wishlist of stays you like across your devices.',
          );
          return;
        }
        ref.read(favoritesProvider.notifier).toggle(listingId);
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
        ]),
        child: HeroIcon(
          HeroIcons.heart,
          style: isFavorite ? HeroIconStyle.solid : HeroIconStyle.outline,
          size: 16,
          color: isFavorite ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _priceTag(Listing listing) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
        ]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(formatNaira(listing.displayRate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 2),
            Text('/ ${listing.displayUnitLabel}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _pillBadge({required IconData icon, required String label}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
        ]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      );

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        child: Icon(LucideIcons.house, size: 40, color: Colors.grey.shade400),
      );
}
