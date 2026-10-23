import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:staynaija/core/router/app_router.dart';
import 'package:staynaija_shared/core/map/tile_cache.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the map tile cache before the first frame - Explore is built eagerly
  // inside the shell's IndexedStack, so its map can request tiles immediately.
  try {
    final cacheDir = await getTemporaryDirectory();
    await TileCache.init(cacheDir.path);
  } catch (_) {
    // Cache is an optimisation; the map falls back to plain network tiles.
  }

  runApp(const ProviderScope(child: StayNaijaApp()));
}

class StayNaijaApp extends ConsumerWidget {
  const StayNaijaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'iStay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
