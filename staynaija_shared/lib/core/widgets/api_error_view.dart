import 'package:flutter/material.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

/// A consistent "something went wrong" state for a failed API call, in place
/// of a bare error `Text` - distinguishes network/connectivity failures
/// (where a retry often just works) from 400s (the request itself was
/// wrong - retrying the same thing won't help) and 500s (StayNaija's own
/// fault, and often transient), each with its own icon and headline, plus a
/// retry button wherever the caller actually has something to retry.
class ApiErrorView extends StatelessWidget {
  const ApiErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;

  /// Left null when the caller has no sensible retry action (e.g. a one-off
  /// mutation already resolved) - the button is omitted rather than wired to
  /// a no-op.
  final VoidCallback? onRetry;

  /// Tighter padding/sizing for use inline within a list or card rather than
  /// as a screen's only content.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final kind = classifyApiError(error);
    final IconData icon;
    final String title;
    final String message;
    switch (kind) {
      case ApiErrorKind.network:
        icon = LucideIcons.wifi;
        title = "You're offline";
        message = 'Check your connection and try again.';
      case ApiErrorKind.serverError:
        icon = LucideIcons.triangleAlert;
        title = 'Something went wrong on our end';
        message = "We're looking into it - please try again in a moment.";
      case ApiErrorKind.badRequest:
        icon = LucideIcons.circleHelp;
        title = "That didn't go through";
        message = apiErrorMessage(error);
      case ApiErrorKind.unknown:
        icon = LucideIcons.circleHelp;
        title = 'Something went wrong';
        message = apiErrorMessage(error);
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 20 : 48,
        horizontal: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 30 : 38, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
