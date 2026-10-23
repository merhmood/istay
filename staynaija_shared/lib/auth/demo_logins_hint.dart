import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

/// Server-decided settings the backend's environment controls (see
/// `GET /config`): whether to advertise demo logins, and how prospective hosts
/// can reach the team.
class AppConfig {
  const AppConfig({this.showDemoLogins = false, this.supportWhatsapp, this.supportEmail});

  final bool showDemoLogins;
  final String? supportWhatsapp;
  final String? supportEmail;

  bool get hasSupportContact => supportWhatsapp != null || supportEmail != null;
}

/// Fails closed: if the request fails, demo logins stay hidden and no support
/// contact is offered, rather than showing demo data in production.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    final response = await DioClient.instance.dio.get('/config');
    final data = response.data as Map;
    String? text(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return AppConfig(
      showDemoLogins: data['show_demo_logins'] == true,
      supportWhatsapp: text('support_whatsapp'),
      supportEmail: text('support_email'),
    );
  } catch (_) {
    return const AppConfig();
  }
});

final showDemoLoginsProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).valueOrNull?.showDemoLogins ?? false,
);

class DemoLoginsHint extends ConsumerWidget {
  const DemoLoginsHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showDemoLoginsProvider)) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: const Text(
        'Demo logins (after running seed.py):\n'
        'guest@staynaija.demo / host@staynaija.demo\n'
        'password: password123',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}
