import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

class BookingRequestedScreen extends StatelessWidget {
  const BookingRequestedScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.hourglass, size: 72, color: AppColors.accent),
              const SizedBox(height: 24),
              Text('Request sent!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                "The host will review your request. You'll be notified once they respond, and you can pay once they accept.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: () => context.go('/trips'), child: const Text('View my trips')),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.checkCircle, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text('Booking confirmed!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Your payment was successful. The host has been notified.', textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: () => context.go('/trips'), child: const Text('View my trips')),
            ],
          ),
        ),
      ),
    );
  }
}
