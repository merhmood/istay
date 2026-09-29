import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija/core/widgets/animated_favorite_icon.dart';
import 'package:staynaija/core/widgets/sign_in_prompt.dart';
import 'package:staynaija/features/discovery/favorites_provider.dart';

class ListingCard extends ConsumerWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverPhoto = listing.photos.isNotEmpty ? listing.photos.first.url : null;
    final hasPower = listing.hasGenerator || listing.hasInverter || listing.has24hrElectricity;
    final hasSecurity = listing.isGatedEstate || listing.hasSecurityGuard || listing.hasCctv;
    final isFavorite = ref.watch(favoritesProvider.select((ids) => ids.contains(listing.id)));

    return GestureDetector(
      onTap: onTap,
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
                    aspectRatio: 1,
                    child: AppImage(url: coverPhoto),
                  ),
                  if (listing.instantBook)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Badge(
                        icon: LucideIcons.zap,
                        label: 'Instant',
                        background: Colors.white,
                        foreground: AppColors.primary,
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        if (isSignedOut(ref)) {
                          promptSignIn(
                            context,
                            title: 'Save this place',
                            message: 'Sign in to keep a wishlist of stays you like across your devices.',
                          );
                          return;
                        }
                        ref.read(favoritesProvider.notifier).toggle(listing.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                        ]),
                        child: AnimatedFavoriteIcon(isFavorite: isFavorite, size: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${listing.city} · ${listing.neighborhoodLandmark}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (hasPower || hasSecurity) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (hasPower) Icon(LucideIcons.zap, size: 13, color: AppColors.textSecondary),
                        if (hasPower && hasSecurity) const SizedBox(width: 6),
                        if (hasSecurity) Icon(LucideIcons.shieldCheck, size: 13, color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(formatNaira(listing.displayRate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 3),
                      Text('/ ${listing.displayUnitLabel}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.background, required this.foreground});

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}
