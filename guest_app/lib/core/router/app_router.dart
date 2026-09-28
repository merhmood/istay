import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija/core/router/app_shell.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija/features/auth/login_screen.dart';
import 'package:staynaija/features/auth/register_screen.dart';
import 'package:staynaija/features/booking/booking_flow_screen.dart';
import 'package:staynaija/features/booking/booking_status_screens.dart';
import 'package:staynaija/features/booking/checkout_screen.dart';
import 'package:staynaija/features/booking/my_bookings_screen.dart';
import 'package:staynaija/features/discovery/explore_screen.dart';
import 'package:staynaija/features/discovery/home_screen.dart';
import 'package:staynaija/features/discovery/saved_listings_screen.dart';
import 'package:staynaija/features/listing_detail/listing_detail_screen.dart';
import 'package:staynaija/features/messaging/chat_screen.dart';
import 'package:staynaija/features/messaging/conversations_list_screen.dart';
import 'package:staynaija/features/payments/escrow_screen.dart';
import 'package:staynaija/features/payments/payments_screen.dart';
import 'package:staynaija/features/profile/profile_screen.dart';
import 'package:staynaija/features/support/support_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

/// Routes that act on a specific account - booking, paying, chatting, or
/// anything listing what *this* user has saved or spent. Everything else
/// (home, explore, search, listing details) is browsable signed out.
const _accountRoutePrefixes = [
  '/saved',
  '/payments',
  '/escrow',
  '/book/',
  '/checkout/',
  '/booking-requested/',
  '/booking-confirmed/',
  '/chat/',
];

bool _requiresAccount(String location) =>
    _accountRoutePrefixes.any((prefix) => location == prefix || location.startsWith(prefix));

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (authState.status == AuthStatus.unknown) return null;
      if (authState.status == AuthStatus.authenticated && loggingIn) return '/';
      // Browsing is open: only routes that act on a specific account are
      // bounced to sign-in. The shell tabs that need an account render their
      // own inline prompt instead, so the bottom nav never dead-ends.
      if (authState.status == AuthStatus.unauthenticated && _requiresAccount(state.matchedLocation)) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/explore', builder: (context, state) => const ExploreScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/trips', builder: (context, state) => const MyBookingsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/messages', builder: (context, state) => const ConversationsListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/saved', builder: (context, state) => const SavedListingsScreen()),
      GoRoute(path: '/payments', builder: (context, state) => const PaymentsScreen()),
      GoRoute(path: '/escrow', builder: (context, state) => const EscrowScreen()),
      GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
      GoRoute(
        path: '/listing/:id',
        builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:listingId',
        builder: (context, state) => BookingFlowScreen(listingId: state.pathParameters['listingId']!),
      ),
      GoRoute(
        path: '/booking-requested/:bookingId',
        builder: (context, state) => BookingRequestedScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/checkout/:bookingId',
        builder: (context, state) => CheckoutScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/booking-confirmed/:bookingId',
        builder: (context, state) => BookingConfirmedScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatScreen(conversationId: state.pathParameters['conversationId']!),
      ),
    ],
  );
});
