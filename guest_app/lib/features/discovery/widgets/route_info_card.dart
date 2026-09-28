import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija/features/discovery/services/directions_service.dart';

/// Card shown when a listing is picked on the Explore map. It leads with the
/// listing's details; directions are opt-in via the navigate button, and the
/// route summary only appears once the guest asks for it.
class RouteInfoCard extends StatelessWidget {
  const RouteInfoCard({
    super.key,
    required this.listing,
    required this.route,
    required this.isLoadingRoute,
    required this.routeError,
    required this.onBack,
    required this.onViewListing,
    required this.onShowDirections,
    required this.onGetThere,
  });

  final Listing listing;
  final RouteResult? route;
  final bool isLoadingRoute;
  final String? routeError;
  final VoidCallback onBack;
  final VoidCallback onViewListing;
  final VoidCallback onShowDirections;

  /// Opens the ride/maps options sheet.
  final VoidCallback onGetThere;

  @override
  Widget build(BuildContext context) {
    final coverPhoto = listing.photos.isNotEmpty ? listing.photos.first.url : null;
    final hasRouteInfo = isLoadingRoute || routeError != null || route != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: AppImage(url: coverPhoto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${listing.city} · ${listing.neighborhoodLandmark}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(formatNaira(listing.displayRate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(' / ${listing.displayUnitLabel}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      children: [
                        _stat(LucideIcons.bedDouble, '${listing.bedrooms} bed'),
                        _stat(LucideIcons.bath, '${listing.bathrooms} bath'),
                        _stat(LucideIcons.users, '${listing.maxGuests}'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (hasRouteInfo) ...[
            const Divider(height: 20),
            if (isLoadingRoute)
              const Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Finding route...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              )
            else if (routeError != null)
              Text(routeError!, style: const TextStyle(color: AppColors.error, fontSize: 12))
            else if (route != null)
              Row(
                children: [
                  Icon(LucideIcons.navigation, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('${route!.distanceLabel} · ${route!.durationLabel} drive', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
          ],
          const SizedBox(height: 12),
          // All three actions share one height and corner radius: previously an
          // outlined pill, a 40px icon button and a 42px filled button sat side
          // by side at three different sizes and shapes.
          Row(
            children: [
              SizedBox(
                height: _actionHeight,
                width: _actionHeight,
                child: OutlinedButton(
                  style: _squareActionStyle(),
                  onPressed: onShowDirections,
                  child: Icon(
                    LucideIcons.route,
                    size: 17,
                    color: route != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Hands off to a ride or navigation app: our in-app route has no
              // traffic data, which matters most exactly when someone is about
              // to travel there. Which app is a price decision that changes
              // trip to trip, so this opens the choice rather than assuming.
              SizedBox(
                height: _actionHeight,
                width: _actionHeight,
                child: OutlinedButton(
                  style: _squareActionStyle(),
                  onPressed: onGetThere,
                  child: Icon(LucideIcons.navigation, size: 17, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: _actionHeight,
                  child: ElevatedButton(
                    // Overrides the theme's full-width minimumSize; see the note
                    // on elevatedButtonTheme about infinite width inside a Row.
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, _actionHeight)),
                    onPressed: onViewListing,
                    child: const Text('View details', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _actionHeight = 44.0;

  /// Square icon action. Corner radius and border colour come from the shared
  /// theme, so only the square sizing needs setting here.
  ButtonStyle _squareActionStyle() => OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(_actionHeight, _actionHeight),
      );

  Widget _stat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}
