import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

/// Network image with disk caching, a shimmering skeleton and a fade-in.
///
/// `Image.network` keeps nothing on disk, so every app restart re-downloaded
/// every listing photo and the feed sat blank on a slow connection. This caches
/// to disk, so a photo is fetched once and is instant on every later view.
///
/// While loading it shows a moving shimmer rather than a static grey block -
/// a still placeholder reads as "broken", a moving one reads as "coming".
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIcon = LucideIcons.house,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (url == null || url!.isEmpty) {
      image = _fallback();
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: const Duration(milliseconds: 250),
        // No fade on the placeholder->image swap out of cache: an already-cached
        // photo should appear instantly rather than animating in every time.
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (context, _) => const _Shimmer(),
        errorWidget: (context, _, _) => _fallback(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _fallback() => Builder(
        builder: (context) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: Icon(fallbackIcon, size: 28, color: Colors.grey.shade400),
        ),
      );
}

/// A pale sweep moving across a grey block, at a deliberately unhurried pace so
/// it suggests loading rather than flickering.
class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Sweep travels from off-screen left to off-screen right.
        final position = _controller.value * 2 - 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(position - 0.6, -0.2),
              end: Alignment(position + 0.6, 0.2),
              colors: [Colors.grey.shade200, Colors.grey.shade100, Colors.grey.shade200],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
