import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({required this.points, required this.distanceMeters, required this.durationSeconds});

  String get distanceLabel =>
      distanceMeters >= 1000 ? '${(distanceMeters / 1000).toStringAsFixed(1)} km' : '${distanceMeters.round()} m';

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return '${hours}h ${remaining}min';
  }
}

/// Draws a driving route between two points using OSRM's free public demo router
/// (router.project-osrm.org) - no API key needed, but it's a shared demo instance
/// (rate-limited, not meant for production traffic). Swap in a self-hosted OSRM
/// instance or a commercial routing provider before shipping this for real.
class DirectionsService {
  final Dio _dio = Dio();

  Future<RouteResult> getRoute({required LatLng from, required LatLng to}) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    final response = await _dio.get(url);
    final route = response.data['routes'][0];
    final coordinates = route['geometry']['coordinates'] as List;
    final points = coordinates.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
    return RouteResult(
      points: points,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }
}
