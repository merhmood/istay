import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

/// A heart icon that pops with a little bounce the moment it becomes
/// favorited, instead of silently swapping from outline to solid.
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
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  // Overshoots past full size, settles back under it, then eases home - the
  // familiar "like button" pop rather than a linear grow.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.85).chain(CurveTween(curve: Curves.easeInOut)), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant AnimatedFavoriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the save transition gets the bounce - un-saving, and the initial
    // build syncing to an already-saved listing, just show the end state.
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
    return ScaleTransition(
      scale: _scale,
      child: HeroIcon(
        HeroIcons.heart,
        style: widget.isFavorite ? HeroIconStyle.solid : HeroIconStyle.outline,
        size: widget.size,
        color: widget.isFavorite ? widget.activeColor : widget.inactiveColor,
      ),
    );
  }
}
