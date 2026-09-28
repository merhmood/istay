import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:staynaija_shared/core/map/tile_cache.dart';

// Screens that show this layer also render its attribution, so they get
// TileSource from the same import rather than needing a second one.
export 'package:staynaija_shared/core/map/tile_cache.dart' show TileSource;

/// The basemap, in the app's own monochrome.
///
/// Rather than pick one of MapTiler's ready-made grey styles - all of which are
/// built for data overlays and drop half the street labels - this fetches the
/// fully-labelled street style and desaturates it here. The result is our own
/// look over every label MapTiler publishes, adjustable by two numbers instead
/// of by whatever a hosted style happens to offer.
///
/// Only the tiles pass through the filter. Price markers, route lines and the
/// location dot are separate layers above it, so they keep their brand colour
/// and stand out all the more against a grey map - which is the point.
class BrandTileLayer extends StatelessWidget {
  const BrandTileLayer({
    super.key,
    required this.userAgentPackageName,
    this.maxNativeZoom = 20,
    this.panBuffer,
    this.keepBuffer,
  });

  final String userAgentPackageName;
  final int maxNativeZoom;

  /// Off-screen tile prefetch. The Explore map sets these down, since the disk
  /// cache makes re-panning cheap and fetching less gets the first frame up
  /// sooner on a slow connection.
  final int? panBuffer;
  final int? keepBuffer;

  /// Rec.709 luminance weights - the standard perceptual mix. A naive
  /// (R+G+B)/3 muddies greens and blues, which on a map means parks and water
  /// turn the same grey as the land around them.
  static const _lumaRed = 0.2126;
  static const _lumaGreen = 0.7152;
  static const _lumaBlue = 0.0722;

  /// Pulled back from 1.0 so the map recedes behind the markers, then lifted
  /// toward white so it reads as a light backdrop rather than a grey slab.
  /// Chosen by applying this exact matrix to a real Victoria Island tile and
  /// comparing the output.
  static const _contrast = 0.85;
  static const _lift = 28.0;

  /// The 4x5 matrix `ColorFilter.matrix` expects, row-major, as
  /// `out = m0*R + m1*G + m2*B + m3*A + m4` per channel on 0..255 values.
  /// Alpha is passed through untouched so tile edges stay clean.
  static const ColorFilter monochrome = ColorFilter.matrix(<double>[
    _lumaRed * _contrast, _lumaGreen * _contrast, _lumaBlue * _contrast, 0, _lift,
    _lumaRed * _contrast, _lumaGreen * _contrast, _lumaBlue * _contrast, 0, _lift,
    _lumaRed * _contrast, _lumaGreen * _contrast, _lumaBlue * _contrast, 0, _lift,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: monochrome,
      child: TileLayer(
        urlTemplate: TileSource.urlTemplate,
        userAgentPackageName: userAgentPackageName,
        tileProvider: TileCache.provider(),
        retinaMode: TileSource.hasKey && RetinaMode.isHighDensity(context),
        maxNativeZoom: maxNativeZoom,
        panBuffer: panBuffer ?? 1,
        keepBuffer: keepBuffer ?? 2,
      ),
    );
  }
}
