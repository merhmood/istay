import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/favorites/favorite_repository.dart';

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier(this._repository) : super({}) {
    _load();
  }

  final FavoriteRepository _repository;

  Future<void> _load() async {
    try {
      state = await _repository.listIds();
    } catch (_) {
      // Leave state empty; individual toggle actions will still work and heart
      // icons will just start unfilled until the next successful refresh.
    }
  }

  bool isFavorite(String listingId) => state.contains(listingId);

  Future<void> toggle(String listingId) async {
    final wasFavorite = state.contains(listingId);
    state = wasFavorite ? ({...state}..remove(listingId)) : ({...state}..add(listingId));
    try {
      if (wasFavorite) {
        await _repository.remove(listingId);
      } else {
        await _repository.add(listingId);
      }
    } catch (_) {
      // Revert the optimistic update if the request failed.
      state = wasFavorite ? ({...state}..add(listingId)) : ({...state}..remove(listingId));
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier(ref.watch(favoriteRepositoryProvider));
});
