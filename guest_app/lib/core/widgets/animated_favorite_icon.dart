import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

/// A heart icon that pops with a bounce, a little wobble, a ring pulse and a
/// particle burst the moment it becomes favorited, instead of silently
/// swapping from outline to solid.
///
/// Purely a presentation wrapper - callers keep their own container styling,
/// tap handling and sign-in gating, and just render this in place of a raw
/// `HeroIcon(HeroIcons.heart, ...)`.
class AnimatedFavoriteIcon extends StatefulWidget {
  const AnimatedFavoriteIcon({
    super.key,
    required this.isFavorite,
    this.size = 20,
    this.activeColor = AppColors.error,
    this.inactiveColor = AppColors.textSecondary,
  });

  final bool isFavorite;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  @override
  State<AnimatedFavoriteIcon> createState() => _AnimatedFavoriteIconState();
}

class _AnimatedFavoriteIconState extends State<AnimatedFavoriteIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  // Overshoots well past full size, dips under it, then eases home - a
  // deliberately big swing rather than a subtle grow, so it reads clearly
  // even at a 13-20px icon size.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.85).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.85, end: 0.75).chain(CurveTween(curve: Curves.easeInOut)), weight: 22),
    TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 23),
  ]).animate(_controller);

  // A small wiggle layered onto the scale so the pop doesn't read as a flat
  // zoom - settles out well before the bounce finishes.
  late final Animation<double> _rotation = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.22), weight: 30),
    TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.14), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.14, end: 0.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.75, curve: Curves.easeOut)));

  // An outlined ring (not a filled blob) that expands out from the heart and
  // fades - starts at 0 opacity so it's genuinely invisible until a tap
  // drives the controller forward.
  late final Animation<double> _ringScale = Tween<double>(begin: 0.3, end: 2.6)
      .chain(CurveTween(curve: const Interval(0.0, 0.55, curve: Curves.easeOut)))
      .animate(_controller);

  late final Animation<double> _ringOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.7), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
  ]).animate(_controller);

  // Drives a handful of small dots flung outward from the heart - the
  // "confetti" part of the burst. Interval keeps it 0 at rest and 0 again
  // once it's done, painting nothing outside that window (see
  // _BurstPainter.paint's early return).
  late final Animation<double> _particleProgress = CurvedAnimation(parent: _controller, curve: const Interval(0.05, 0.8, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant AnimatedFavoriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the save transition gets the animation - un-saving, and the
    // initial build syncing to an already-saved listing, just show the end
    // state with no animation.
    if (widget.isFavorite && !oldWidget.isFavorite) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      // The burst paints past the icon's own footprint on purpose - Stack
      // still only *reports* widget.size to its parent, since the burst
      // layer below is `Positioned` - only non-positioned children count
      // towards a Stack's own layout size, so it can paint past the tight
      // circular chip each call site wraps this in without growing it.
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -widget.size,
          top: -widget.size,
          width: widget.size * 3,
          height: widget.size * 3,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _particleProgress,
              builder: (context, _) => CustomPaint(
                painter: _BurstPainter(progress: _particleProgress.value, color: widget.activeColor),
              ),
            ),
          ),
        ),
        ScaleTransition(
          scale: _ringScale,
          child: FadeTransition(
            opacity: _ringOpacity,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.activeColor, width: 2)),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: Listenable.merge([_scale, _rotation]),
          builder: (context, child) => Transform.rotate(
            angle: _rotation.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
          child: HeroIcon(
            HeroIcons.heart,
            style: widget.isFavorite ? HeroIconStyle.solid : HeroIconStyle.outline,
            size: widget.size,
            color: widget.isFavorite ? widget.activeColor : widget.inactiveColor,
          ),
        ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _particleCount = 8;

  @override
  void paint(Canvas canvas, Size size) {
    // Nothing to draw at rest (progress == 0) or once the burst has fully
    // played out (progress == 1) - this is what keeps the dots from ever
    // being visible on an icon that hasn't just been tapped.
    if (progress <= 0 || progress >= 1) return;

    final center = size.center(Offset.zero);
    final fade = math.sin(progress * math.pi).clamp(0.0, 1.0);
    final travel = size.shortestSide * (0.32 + 0.8 * progress);
    final dotRadius = size.shortestSide * (0.1 - 0.05 * progress);
    final paint = Paint()..color = color.withValues(alpha: fade);

    for (var i = 0; i < _particleCount; i++) {
      final angle = (2 * math.pi / _particleCount) * i - math.pi / 2;
      final offset = center + Offset(math.cos(angle), math.sin(angle)) * travel;
      canvas.drawCircle(offset, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}
