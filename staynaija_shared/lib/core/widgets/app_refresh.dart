import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

/// Pull-to-refresh with the app's own loader rather than Material's spinner.
///
/// The Material indicator is an indeterminate spinner from the moment it
/// appears, so the pull itself gives no feedback - you cannot tell how far is
/// far enough until it triggers. This one is *determinate while you drag*: the
/// ring fills in proportion to the pull and the house mark fades up as it arms,
/// so the gesture explains itself. Only once it is actually fetching does it
/// switch to a continuous sweep.
///
/// Wrapping this in one place keeps every screen's refresh identical.
class AppRefresh extends StatelessWidget {
  const AppRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 44,
    this.edgeOffset = 0,
  });

  /// Re-runs the screen's network request. Should complete only once the new
  /// data has arrived, otherwise the indicator snaps away before the refresh
  /// has visibly done anything.
  final Future<void> Function() onRefresh;
  final Widget child;

  /// How far below the top edge the puck settles.
  final double displacement;

  /// Extra offset for screens whose content starts below a floating app bar.
  final double edgeOffset;

  /// Pull distance that triggers a refresh. Material's default is 100; slightly
  /// shorter feels quicker without arming by accident.
  static const _armedOffset = 90.0;

  static const _puckSize = 38.0;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      offsetToArmed: _armedOffset,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            // Clamped so an enthusiastic overscroll doesn't fling the puck
            // down the screen; the list keeps following the finger, the puck
            // does not.
            final progress = controller.value.clamp(0.0, 1.0);
            final top = edgeOffset + displacement * progress - _puckSize * (1 - progress);

            return Stack(
              children: [
                // The content follows the pull, which is what makes the puck
                // look like it is emerging from behind it.
                Transform.translate(
                  offset: Offset(0, controller.value * displacement),
                  child: child,
                ),
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      // Fades in over the first third of the pull so a stray
                      // one-pixel scroll doesn't flash the puck.
                      opacity: (progress * 3).clamp(0.0, 1.0),
                      child: _Puck(controller: controller),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: child,
    );
  }
}

/// The white disc with the brand ring and house mark.
class _Puck extends StatefulWidget {
  const _Puck({required this.controller});

  final IndicatorController controller;

  @override
  State<_Puck> createState() => _PuckState();
}

class _PuckState extends State<_Puck> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant _Puck oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  /// The ring only spins while data is actually in flight. During the drag its
  /// rotation is driven by the finger instead, which is the whole point.
  void _syncSpin() {
    final shouldSpin = widget.controller.isLoading || widget.controller.isFinalizing;
    if (shouldSpin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!shouldSpin && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isLoading = controller.isLoading || controller.isFinalizing;
    final progress = controller.value.clamp(0.0, 1.0);

    return Container(
      width: AppRefresh._puckSize,
      height: AppRefresh._puckSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          return CustomPaint(
            painter: _RingPainter(
              // While dragging, the ring's rotation tracks the finger so the
              // mark appears to wind up; while loading it free-runs.
              rotation: isLoading ? _spin.value * 2 * math.pi : progress * math.pi,
              sweep: isLoading ? math.pi * 1.1 : progress * 2 * math.pi,
            ),
            child: Center(
              child: Icon(
                LucideIcons.house,
                size: 15,
                // Dim until the pull is nearly enough, so the mark lighting up
                // is the cue that letting go will refresh.
                color: AppColors.primary.withValues(
                  alpha: isLoading ? 1.0 : (0.25 + progress * 0.75).clamp(0.0, 1.0),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.rotation, required this.sweep});

  final double rotation;
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 3.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(inset);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.primary.withValues(alpha: 0.12);
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, track);

    if (sweep <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;
    // Starts at 12 o'clock rather than 3, so a part-filled ring reads as a
    // progress dial instead of a random arc.
    canvas.drawArc(arcRect, -math.pi / 2 + rotation, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.sweep != sweep;
}
