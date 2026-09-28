import 'package:geolocator/geolocator.dart';

/// Thin wrapper around geolocator's permission dance. Returns null (rather than
/// throwing) whenever location can't be obtained, so callers can fall back to a
/// city-centroid default instead of crashing.
class LocationService {
  /// Cached fix from a previous session/app - returns instantly, so the UI can
  /// show something location-aware while a fresh GPS fix is still resolving.
  Future<Position?> getLastKnownPosition() async {
    if (!await _hasPermission()) return null;
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// `accuracy` defaults to medium - plenty for "which town am I in" and it
  /// resolves faster, which is what every "my location" button on a search
  /// map wants. A caller placing a pin that has to be right to within a few
  /// metres (the host's exact-spot picker) should pass `LocationAccuracy.best`
  /// instead; that fix takes longer, so pair it with a longer `timeLimit`.
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    if (!await _hasPermission()) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeLimit),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied && permission != LocationPermission.deniedForever;
  }
}
