import 'package:flutter/material.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/models/listing.dart';

/// Compact horizontal row used inside the Explore map's bottom drawer.
class ExploreResultTile extends StatelessWidget {
  const ExploreResultTile({super.key, required this.listing, required this.onTap, this.selected = false});

  final Listing listing;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final coverPhoto = listing.photos.isNotEmpty ? listing.photos.first.url : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: AppImage(url: coverPhoto),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                    '${listing.city} · ${listing.neighborhoodLandmark}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(formatNaira(listing.displayRate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 3),
                      Text('/ ${listing.displayUnitLabel}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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
