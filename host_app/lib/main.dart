import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:staynaija_host/core/onboarding/onboarding_provider.dart';
import 'package:staynaija_host/core/router/app_router.dart';
import 'package:staynaija_shared/core/map/tile_cache.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Same tile cache as the guest app, so the location picker's map is disk
  // cached rather than refetching on every open.
  try {
    final cacheDir = await getTemporaryDirectory();
    await TileCache.init(cacheDir.path);
  } catch (_) {
    // Cache is an optimisation; the map falls back to plain network tiles.
  }

  // Read up front so the router's redirect has a synchronous answer on the
  // very first frame - see onboarding_provider.dart.
  final hasSeenOnboarding = await loadHasSeenOnboarding();

  runApp(
    ProviderScope(
      overrides: [hasSeenOnboardingProvider.overrideWith((ref) => hasSeenOnboarding)],
      child: const StayNaijaHostApp(),
    ),
  );
}

class StayNaijaHostApp extends ConsumerWidget {
  const StayNaijaHostApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'iStay Host',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
