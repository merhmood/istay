import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija_host/core/onboarding/onboarding_provider.dart';
import 'package:staynaija_host/core/router/app_shell.dart';
import 'package:staynaija_host/features/admin/admin_hosts_screen.dart';
import 'package:staynaija_shared/auth/change_password_screen.dart';
import 'package:staynaija_host/features/host/analytics_screen.dart';
import 'package:staynaija_host/features/auth/login_screen.dart';
import 'package:staynaija_host/features/onboarding/onboarding_screen.dart';
import 'package:staynaija_host/features/host/booking_requests_screen.dart';
import 'package:staynaija_host/features/host/calendar_management_screen.dart';
import 'package:staynaija_host/features/host/create_edit_listing_screen.dart';
import 'package:staynaija_host/features/host/earnings_screen.dart';
import 'package:staynaija_host/features/host/host_dashboard_screen.dart';
import 'package:staynaija_host/features/host/my_listings_screen.dart';
import 'package:staynaija_host/features/messaging/chat_screen.dart';
import 'package:staynaija_host/features/messaging/conversations_list_screen.dart';
import 'package:staynaija_host/features/profile/profile_screen.dart';
import 'package:staynaija_host/features/support/support_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status ||
          previous?.user?.mustChangePassword != next.user?.mustChangePassword) {
        notifyListeners();
      }
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final onOnboarding = state.matchedLocation == '/onboarding';
      // Shown once, before any auth check - a host deciding whether to sign up
      // at all shouldn't be routed to a login form first.
      if (!ref.read(hasSeenOnboardingProvider) && !onOnboarding) return '/onboarding';
      if (ref.read(hasSeenOnboardingProvider) && onOnboarding) return '/';

      final authState = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login';

      if (authState.status == AuthStatus.unknown) return null;
      if (authState.status == AuthStatus.unauthenticated && !loggingIn) return '/login';
      if (authState.status == AuthStatus.authenticated) {
        // An admin-issued temporary password has to be replaced before anything
        // else in the app is reachable.
        final mustChange = authState.user?.mustChangePassword ?? false;
        final onChangePassword = state.matchedLocation == '/change-password';
        if (mustChange && !onChangePassword) return '/change-password';
        if (!mustChange && onChangePassword) return '/';
        if (loggingIn) return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => ChangePasswordScreen(
            forced: true,
            onChanged: () => ref.read(authProvider.notifier).refreshUser(),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const HostDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/listings', builder: (context, state) => const MyListingsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/requests', builder: (context, state) => const BookingRequestsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/messages', builder: (context, state) => const ConversationsListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/earnings', builder: (context, state) => const EarningsScreen()),
      GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
      GoRoute(path: '/admin/hosts', builder: (context, state) => const AdminHostsScreen()),
      GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
      GoRoute(path: '/listings/new', builder: (context, state) => const CreateEditListingScreen()),
      GoRoute(
        path: '/listings/:id/edit',
        builder: (context, state) => CreateEditListingScreen(existing: state.extra as Listing?),
      ),
      GoRoute(
        path: '/listings/:id/calendar',
        builder: (context, state) => CalendarManagementScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatScreen(conversationId: state.pathParameters['conversationId']!),
      ),
    ],
  );
});
