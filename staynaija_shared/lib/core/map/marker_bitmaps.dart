import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

/// Draws map markers as bitmaps.
///
/// Google Maps markers are images, not widgets, so the drawn teardrop and price
/// pill used elsewhere in the app have to be rasterised. Everything here paints
/// onto a canvas at device pixel ratio and encodes to PNG.
///
/// Results are cached by their inputs: building a bitmap costs an image encode,
/// and a map full of price markers would otherwise re-encode on every rebuild.
class MarkerBitmaps {
  MarkerBitmaps._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Price pill with a small tail, matching the in-app price markers.
  static Future<BitmapDescriptor> priceLabel(
    String text, {
    required bool selected,
    double devicePixelRatio = 3,
  }) async {
    final key = 'price:$text:$selected:$devicePixelRatio';
    final cached = _cache[key];
    if (cached != null) return cached;

    final scale = devicePixelRatio;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 13 * scale,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final paddingX = 12.0 * scale;
    final paddingY = 7.0 * scale;
    final tailHeight = 6.0 * scale;
    final width = painter.width + paddingX * 2;
    final pillHeight = painter.height + paddingY * 2;
    final height = pillHeight + tailHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, pillHeight),
      Radius.circular(pillHeight / 2),
    );
    // Soft shadow so the pill lifts off the map rather than sitting flat on it.
    canvas.drawRRect(
      pill.shift(Offset(0, 1.5 * scale)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * scale),
    );
    canvas.drawRRect(pill, Paint()..color = selected ? AppColors.primary : Colors.white);

    // Tail pointing at the coordinate.
    final tail = Path()
      ..moveTo(width / 2 - 5 * scale, pillHeight - 1)
      ..lineTo(width / 2, height)
      ..lineTo(width / 2 + 5 * scale, pillHeight - 1)
      ..close();
    canvas.drawPath(tail, Paint()..color = selected ? AppColors.primary : Colors.white);

    painter.paint(canvas, Offset(paddingX, paddingY));

    final descriptor = await _encode(recorder, width, height);
    _cache[key] = descriptor;
    return descriptor;
  }

  /// Teardrop property pin, the same shape the in-app MapPin paints.
  static Future<BitmapDescriptor> propertyPin({
    Color color = AppColors.primary,
    double size = 48,
    double devicePixelRatio = 3,
  }) async {
    final key = 'pin:${color.toARGB32()}:$size:$devicePixelRatio';
    final cached = _cache[key];
    if (cached != null) return cached;

    final dimension = size * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final headRadius = dimension * 0.34;
    final headCentre = Offset(dimension / 2, headRadius + dimension * 0.04);
    final tip = Offset(dimension / 2, dimension * 0.95);

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

    canvas.drawPath(
      path.shift(Offset(0, 1.5 * devicePixelRatio)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * devicePixelRatio),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = dimension * 0.055,
    );
    // Hollow centre, so the pin reads as a marker rather than a solid blob.
    canvas.drawCircle(headCentre, headRadius * 0.34, Paint()..color = Colors.white);

    final descriptor = await _encode(recorder, dimension, dimension);
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<BitmapDescriptor> _encode(ui.PictureRecorder recorder, double width, double height) async {
    final image = await recorder.endRecording().toImage(width.ceil(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
