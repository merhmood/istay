import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';

/// Disk-backed cache for map tiles.
///
/// Without this every pan and zoom re-fetches tiles from OSM's public servers,
/// which is the main reason the map took so long to appear. Tiles are
/// effectively immutable, so they are cached aggressively and served from disk
/// on the next visit; `hitCacheOnNetworkFailure` also keeps the last-seen map
/// on screen when the phone drops its connection instead of going blank.
/// Map tile source.
///
/// MapTiler serves genuine @2x retina tiles, which are both sharper and four
/// times fewer requests than simulating retina off 256px OSM tiles. It needs a
/// free API key; without one we fall back to plain OSM so the map still works.
class TileSource {
  TileSource._();

  static const _mapTilerKey = String.fromEnvironment('MAPTILER_KEY');

  /// The richest style available - it is turned monochrome in the app rather
  /// than fetched that way. See [BrandTileLayer].
  ///
  /// Every off-the-shelf monochrome style was tried first, by fetching the same
  /// Victoria Island tile in each and counting what survived:
  ///
  ///   streets-v2     full colour, ~9 labels + POI pins + yellow arterials
  ///   basic-v2       muted mono, 4 street labels
  ///   toner-v2       true black & white, 4 street labels
  ///   backdrop       mono, 2 labels
  ///   dataviz-light  mono, 2 labels
  ///
  /// The monochrome styles are all built for data overlays, so they throw away
  /// half the street names - and street names are precisely how people here
  /// identify a place. "Ahmadu Bello Way" locates a listing in a way a grey
  /// polygon cannot.
  ///
  /// Desaturating the full-colour style client-side gets both: our own
  /// monochrome look, tuned by two numbers we control, over every label
  /// MapTiler publishes.
  static const _mapTilerStyle = 'streets-v2';

  static bool get hasKey => _mapTilerKey.isNotEmpty;

  /// `{r}` resolves to "@2x" on high-density screens, giving real retina tiles.
  static String get urlTemplate => hasKey
      ? 'https://api.maptiler.com/maps/$_mapTilerStyle/{z}/{x}/{y}{r}.png?key=$_mapTilerKey'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static String get attribution => hasKey ? 'MapTiler' : 'OpenStreetMap contributors';
}

class TileCache {
  TileCache._();

  static CacheStore? _store;

  /// Must be awaited before the first map builds - `main()` does this.
  static Future<void> init(String cacheDirectory) async {
    _store ??= FileCacheStore('$cacheDirectory/map_tiles');
  }

  /// A tile provider backed by the cache. Falls back to a plain network
  /// provider if init() hasn't run, so the map still works either way.
  static TileProvider provider() {
    final headers = {'User-Agent': 'iStay/1.0 (https://staynaija.example)'};
    final store = _store;
    if (store == null) return NetworkTileProvider(headers: headers);
    return CachedTileProvider(
      store: store,
      headers: headers,
      maxStale: const Duration(days: 30),
    );
  }
}
