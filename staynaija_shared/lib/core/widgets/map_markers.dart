import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

/// A proper teardrop map pin, drawn rather than borrowed from an icon font.
///
/// Icon-font pins render as a flat outline with no ground contact, so they look
/// like a sticker on the map. This paints a filled teardrop with a white collar,
/// a drop shadow and a soft ellipse on the ground beneath it, so the marker
/// reads as standing on the map.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    this.color = AppColors.primary,
    this.icon,
    this.size = 44,
  });

  final Color color;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MapPinPainter(color: color),
        child: icon == null
            ? null
            : Align(
                // The icon sits in the circular head, not the centre of the box.
                alignment: const Alignment(0, -0.42),
                child: Icon(icon, size: size * 0.32, color: Colors.white),
              ),
      ),
    );
  }
}

class _MapPinPainter extends CustomPainter {
  _MapPinPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Ground shadow: a squashed ellipse under the tip, so the pin looks planted.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(width / 2, height * 0.955), width: width * 0.34, height: height * 0.075),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    final headRadius = width * 0.34;
    final headCentre = Offset(width / 2, headRadius + height * 0.04);
    final tip = Offset(width / 2, height * 0.93);

    // Teardrop: the two tangent lines from the tip to the head circle, closed
    // by the major arc around the back of the head.
    final distance = (tip - headCentre).distance;
    final tangentAngle = math.acos(headRadius / distance);
    final toTip = math.atan2(tip.dy - headCentre.dy, tip.dx - headCentre.dx);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        headCentre.dx + headRadius * math.cos(toTip + tangentAngle),
        headCentre.dy + headRadius * math.sin(toTip + tangentAngle),
      )
      ..arcTo(
        Rect.fromCircle(center: headCentre, radius: headRadius),
        toTip + tangentAngle,
        2 * (math.pi - tangentAngle),
        false,
      )
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 3, false);
    canvas.drawPath(path, Paint()..color = color);
    // White collar, drawn inside the shape so it reads as a rim not an outline.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.055,
    );
  }

  @override
  bool shouldRepaint(_MapPinPainter oldDelegate) => oldDelegate.color != color;
}

/// The "you are here" dot: a solid core, a white collar and a translucent halo
/// suggesting accuracy radius.
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key, this.size = 26, this.color = const Color(0xFF1A73E8)});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
          ),
          Container(
            width: size * 0.54,
            height: size * 0.54,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: size * 0.09),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
