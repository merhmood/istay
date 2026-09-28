import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_host/core/router/app_drawer.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // Drawer lives on the shell so every tab shares it.
      key: ref.watch(appScaffoldKeyProvider),
      drawer: const AppDrawer(),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        backgroundColor: Colors.white,
        // No pill behind the active tab - the solid icon and brand colour
        // already say which tab is selected, matching the guest app.
        indicatorColor: Colors.transparent,
        destinations: [
          _navDestination(HeroIcons.squares2x2, 'Dashboard'),
          // Two buildings rather than one house: a host manages a portfolio of
          // properties, and the single-house glyph read as "home screen".
          _navDestination(HeroIcons.buildingOffice2, 'Listings'),
          _navDestination(HeroIcons.inbox, 'Requests'),
          _navDestination(HeroIcons.chatBubbleLeftRight, 'Messages'),
          _navDestination(HeroIcons.user, 'Profile'),
        ],
      ),
    );
  }
}

/// Outline icon when unselected, solid icon when selected.
///
/// Slightly under Material 3's 24px default - at 22px the five-icon row
/// reads as a touch lighter without losing tap-target size, since the
/// `NavigationDestination` itself still reserves the full-size hit area.
NavigationDestination _navDestination(HeroIcons icon, String label) {
  return NavigationDestination(
    icon: HeroIcon(icon, style: HeroIconStyle.outline, size: 22),
    selectedIcon: HeroIcon(icon, style: HeroIconStyle.solid, color: AppColors.primary, size: 22),
    label: label,
  );
}
