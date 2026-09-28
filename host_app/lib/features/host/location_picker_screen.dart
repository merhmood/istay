import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:geolocator/geolocator.dart';
import 'package:staynaija_shared/core/location/location_service.dart';
import 'package:staynaija_shared/core/map/brand_tile_layer.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/map_markers.dart';

/// Picks the exact point a driver should be sent to.
///
/// Uses a fixed centre crosshair with the map moving underneath, rather than
/// tap-to-place. Tapping is imprecise - a fingertip covers roughly 40m of map at
/// neighbourhood zoom, and the target is hidden beneath the finger at the moment
/// of choosing. Panning under a fixed pin lets the host zoom right in on the gate
/// and place it to within a few metres, which is the difference between a Bolt
/// driver stopping at the right compound or the end of the street.
///
/// Note: a Google Maps version of this screen existed briefly and would be worth
/// restoring if a key is ever configured - its hybrid satellite view let a host
/// see their own roof and compound wall while placing the pin, which no
/// OpenStreetMap basemap can match. See core/map/marker_bitmaps.dart, which is
/// kept for that path.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _lagosFallback = LatLng(6.5244, 3.3792);
  // Building-level detail. The original picker opened at 13, which is district
  // level and far too coarse to place an entrance.
  static const _preciseZoom = 18.0;

  final _mapController = MapController();
  final _locationService = LocationService();

  late LatLng _point;
  double _zoom = _preciseZoom;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _point = widget.initial ?? _lagosFallback;
    // No pin yet usually means the host is standing at the property, so offer
    // their GPS position as the starting point.
    if (widget.initial == null) _useCurrentLocation(silent: true);
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() => _isLocating = true);
    try {
      // Best accuracy, not the medium fix a search map's "my location" button
      // uses - a pin here is meant to be right to within a few metres, so a
      // ~100m-fuzzy GPS reading would just hand the host an inaccurate
      // starting point to correct by hand. Worth the longer resolve time.
      final position = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 30),
      );
      if (!mounted) return;
      if (position == null) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get your location. Check location permission.')),
          );
        }
        return;
      }
      final target = LatLng(position.latitude, position.longitude);
      setState(() => _point = target);
      _mapController.move(target, _preciseZoom);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Below this the pin cannot be placed accurately enough to be useful to a
    // driver, so confirming is blocked with an explanation.
    final isPreciseEnough = _zoom >= 16;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pin the exact spot')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _point,
                    initialZoom: _preciseZoom,
                    maxZoom: 20,
                    // The pin is the map centre, so every camera move updates it.
                    onPositionChanged: (camera, hasGesture) {
                      setState(() {
                        _point = camera.center;
                        _zoom = camera.zoom;
                      });
                    },
                  ),
                  children: [
                    const BrandTileLayer(userAgentPackageName: 'com.staynaija.host'),
                  ],
                ),
                // Fixed crosshair pin, lifted so its tip sits on the map centre.
                const IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 52),
                    child: MapPin(icon: LucideIcons.house, size: 52),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: _HintBanner(isPreciseEnough: isPreciseEnough),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'host-my-location',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    onPressed: _isLocating ? null : () => _useCurrentLocation(),
                    child: _isLocating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(LucideIcons.locate),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 7),
                      // The exact figures handed to Bolt and Uber, so the host
                      // can see what they are actually saving.
                      Text(
                        '${_point.latitude.toStringAsFixed(6)}, ${_point.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, letterSpacing: 0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isPreciseEnough ? () => Navigator.of(context).pop(_point) : null,
                      child: Text(isPreciseEnough ? 'Use this spot' : 'Zoom in to place the pin'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.isPreciseEnough});

  final bool isPreciseEnough;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Icon(
            isPreciseEnough ? LucideIcons.circleCheck : LucideIcons.zoomIn,
            size: 16,
            color: isPreciseEnough ? AppColors.primary : Colors.orange.shade800,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isPreciseEnough
                  ? 'Move the map so the pin sits on your gate or entrance.'
                  : 'Zoom in until you can see the building, then position the pin.',
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
