import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

/// Holds the shell's Scaffold so any branch screen can open the drawer, even
/// though each screen builds its own inner Scaffold (which is what
/// `Scaffold.of` would otherwise find).
final appScaffoldKeyProvider = Provider((ref) => GlobalKey<ScaffoldState>());

/// Hamburger that opens the shell drawer. Screens use this instead of relying
/// on AppBar's automatic drawer button, which only appears on the Scaffold that
/// actually owns the drawer.
class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(LucideIcons.menu, color: color),
      tooltip: 'Menu',
      onPressed: () => ref.read(appScaffoldKeyProvider).currentState?.openDrawer(),
    );
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                    child: user?.avatarUrl == null ? Icon(LucideIcons.user, color: AppColors.primary) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Browsing as guest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        if (user != null)
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Deliberately no Home/Explore/Trips/Messages/Profile here -
                  // those are bottom-nav tabs, and listing them twice makes the
                  // two navigations compete rather than complement.
                  _section('Money'),
                  _DrawerItem(icon: LucideIcons.creditCard, label: 'Payments', route: '/payments'),
                  _DrawerItem(icon: LucideIcons.shieldCheck, label: 'Escrow', route: '/escrow'),
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  _section('Stays'),
                  _DrawerItem(icon: LucideIcons.heart, label: 'Saved', route: '/saved'),
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  _section('Account'),
                  _DrawerItem(icon: LucideIcons.circleHelp, label: 'Help & support', route: '/support'),
                ],
              ),
            ),
            const Divider(height: 1),
            if (user == null)
              ListTile(
                leading: Icon(LucideIcons.logIn, size: 20, color: AppColors.primary),
                title: const Text('Sign in', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/login');
                },
              )
            else
              ListTile(
                leading: Icon(LucideIcons.logOut, size: 20, color: AppColors.error),
                title: const Text('Log out', style: TextStyle(color: AppColors.error, fontSize: 14)),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authProvider.notifier).logout();
                },
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Text('StayNaija', style: brandTextStyle(fontSize: 16, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
      );
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppColors.textPrimary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () {
        // Close first so the drawer doesn't animate over the incoming screen.
        Navigator.of(context).pop();
        context.push(route);
      },
    );
  }
}
