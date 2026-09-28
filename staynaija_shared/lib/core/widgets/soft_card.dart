import 'package:flutter/material.dart';

/// A borderless card: white, generously rounded, lifted by a soft diffuse
/// shadow instead of an outline. Used across trips, messages and profile so
/// grouped content reads as a card without any hard edges.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          boxShadow: [
            // Two stacked shadows: a tight one for definition and a wide, very
            // faint one for lift. Reads softer than a single heavy shadow.
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3, offset: const Offset(0, 1)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
