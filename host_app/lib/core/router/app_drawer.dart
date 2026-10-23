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

class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(LucideIcons.menuFine, size: 26),
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
                          user?.fullName ?? 'Host',
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
                  // Deliberately excludes the five bottom-nav destinations -
                  // listing them twice makes the two navigations compete.
                  _section('Insights'),
                  _DrawerItem(icon: LucideIcons.barChart3, label: 'Analytics', route: '/analytics'),
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  _section('Money'),
                  _DrawerItem(icon: LucideIcons.banknote, label: 'Earnings', route: '/earnings'),
                  // Only staff accounts (set by hand in the database - see
                  // api/v1/admin.py) ever see this section at all.
                  if (user?.isAdmin ?? false) ...[
                    const Divider(height: 20, indent: 20, endIndent: 20),
                    _section('Admin'),
                    _DrawerItem(icon: LucideIcons.users, label: 'Hosts', route: '/admin/hosts'),
                  ],
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  _section('Support'),
                  _DrawerItem(icon: LucideIcons.circleHelp, label: 'Help & support', route: '/support'),
                ],
              ),
            ),
            const Divider(height: 1),
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
              child: Text('iStay Host', style: brandTextStyle(fontSize: 15, color: AppColors.textSecondary)),
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
