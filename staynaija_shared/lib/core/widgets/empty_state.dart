import 'package:flutter/material.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

/// Shown when a screen legitimately has nothing to display.
///
/// An empty screen with one grey sentence reads as broken. This gives the state
/// a shape - a soft illustrated badge, a plain statement of what is missing, a
/// line explaining how it gets filled, and where useful the action that fills
/// it - so "nothing here yet" feels like a stage rather than a failure.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Concentric tinted circles: softer than a bare grey glyph, and it
            // gives the icon enough presence to anchor the block.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 27, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.55),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  // Overrides the theme's full-width minimumSize so the button
                  // hugs its label rather than spanning the screen.
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  onPressed: onAction,
                  icon: actionIcon == null ? const SizedBox.shrink() : Icon(actionIcon, size: 17),
                  label: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Scrollable wrapper, for empty states inside a pull-to-refresh. A plain
/// Center isn't scrollable, so refresh gestures are swallowed exactly when a
/// user is most likely to try one.
class ScrollableEmptyState extends StatelessWidget {
  const ScrollableEmptyState({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
