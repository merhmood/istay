import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija/features/discovery/services/external_maps.dart';

/// Choices for actually getting to a listing.
///
/// Most guests here do not drive themselves, so a plain "directions" button
/// answers the wrong question - they want a ride, and which app they use is a
/// price decision that changes trip to trip. Bolt, Uber and inDrive all operate
/// in Lagos, Abuja and Port Harcourt at different price points, and inDrive's
/// fare-negotiation model means regulars genuinely switch between them.
///
/// Each option opens its app on a confirm-and-pay screen with the listing's
/// exact pinned coordinates already set as the destination, so nobody has to
/// retype an address into a search box. If an app is not installed, or refuses
/// the handoff, the address goes on the clipboard and the guest lands somewhere
/// they can paste it. See ExternalMaps for which URL each app actually honours.
Future<void> showGetThereSheet(
  BuildContext context, {
  required Listing listing,
  Future<void> Function()? onHandoff,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // Explicit rather than left to the framework default: the default is a
    // real 250ms slide, but on this screen the sheet is opened from a button
    // inside a card that itself just finished animating in on map selection,
    // and back-to-back implicit animations on the same route can visually
    // read as "nothing moved" even though each one ran correctly. Naming the
    // curve and duration here guarantees a clearly visible slide regardless.
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 320),
      reverseDuration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    ),
    builder: (_) => _GetThereSheet(listing: listing, onHandoff: onHandoff),
  );
}

class _GetThereSheet extends StatelessWidget {
  const _GetThereSheet({required this.listing, this.onHandoff});

  final Listing listing;

  /// Fired when the guest actually picks something. Asking for a ride to a
  /// place is among the strongest signals of interest we can observe, so the
  /// caller records it against the recommendation profile.
  final Future<void> Function()? onHandoff;

  @override
  Widget build(BuildContext context) {
    final address = ExternalMaps.formatAddress(
      landmark: listing.neighborhoodLandmark,
      city: listing.city,
    );

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Names the destination rather than repeating "Get there", which
            // every option below already says.
            Text(
              listing.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.mapPin, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Option(
              logo: 'assets/Bolt.jpg',
              label: 'Get there with Bolt',
              // Verified on device: Bolt opens straight on its "Confirm
              // destination" screen with the fare already quoted.
              subtitle: 'Destination set - just confirm',
              onTap: () => _handoff(
                context,
                () => ExternalMaps.openBolt(
                  latitude: listing.latitude,
                  longitude: listing.longitude,
                  address: address,
                ),
              ),
            ),
            _Option(
              logo: 'assets/Uber.jpg',
              label: 'Get there with Uber',
              subtitle: 'Destination set - just confirm',
              onTap: () => _handoff(
                context,
                () => ExternalMaps.openUber(
                  latitude: listing.latitude,
                  longitude: listing.longitude,
                  address: address,
                  nickname: listing.title,
                ),
              ),
            ),
            _Option(
              logo: 'assets/Indrive.jpg',
              label: 'Get there with inDrive',
              subtitle: 'Destination set - just confirm',
              onTap: () => _handoff(
                context,
                () => ExternalMaps.openInDrive(
                  latitude: listing.latitude,
                  longitude: listing.longitude,
                  address: address,
                ),
              ),
            ),
            const Divider(height: 22),
            _Option(
              logo: 'assets/GoogleMap.jpg',
              label: 'Find on Google Maps',
              subtitle: 'Directions, traffic and street view',
              onTap: () => _handoff(
                context,
                () => ExternalMaps.openGoogleMaps(
                  latitude: listing.latitude,
                  longitude: listing.longitude,
                  label: listing.title,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // The fallback that always works: a driver who calls can simply be
            // read the address.
            TextButton.icon(
              onPressed: () async {
                await ExternalMaps.copyAddress(address);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied')),
                );
              },
              icon: Icon(LucideIcons.copy, size: 15, color: AppColors.textSecondary),
              label: const Text(
                'Copy address',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handoff(BuildContext context, Future<bool> Function() open) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // Record intent before leaving: once the other app is foregrounded this
    // widget may never get another frame.
    await onHandoff?.call();
    final opened = await open();
    navigator.pop();
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open that app. Try copying the address instead.")),
      );
    }
  }
}

class _Option extends StatelessWidget {
  const _Option({
    this.icon,
    this.tint,
    this.logo,
    required this.label,
    required this.subtitle,
    required this.onTap,
  }) : assert(logo != null || (icon != null && tint != null),
            'An option needs either a brand mark or a tinted glyph');

  /// Fallback glyph for anything without a supplied brand mark.
  final IconData? icon;
  final Color? tint;

  /// Asset path of the app's own logo. These are opaque square JPEGs that
  /// carry their own background colour, so they replace the tinted tile
  /// rather than sitting inside it - the row then reads like a row of app
  /// icons, which is what the guest is actually choosing between.
  final String? logo;

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: logo != null
                    ? Image.asset(logo!, fit: BoxFit.cover)
                    : Container(
                        color: tint!.withValues(alpha: 0.10),
                        child: Icon(icon, size: 19, color: tint),
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
