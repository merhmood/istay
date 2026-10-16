import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/location/location_service.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_shared/models/listing.dart';

export 'package:staynaija_shared/listings/listing_repository.dart';

/// Feeds the guest's location in, when there is one, so "places you may
/// like" doesn't suggest somewhere a plane ride away - see the backend's
/// `MAX_RECOMMENDATION_DISTANCE_KM`. Uses the cached last-known fix rather
/// than requesting a fresh GPS read: this powers the home screen's primary
/// content (and the listing detail screen's "More stays nearby"), so it
/// should never make that content wait on a cold GPS fix the way Explore's
/// fuller location flow can afford to.
final recommendedListingsProvider = FutureProvider.autoDispose((ref) async {
  final position = await LocationService().getLastKnownPosition();
  return ref
      .watch(listingRepositoryProvider)
      .getRecommended(
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
});

class DiscoveryState {
  final ListingFilters filters;
  final List<Listing> results;
  final bool isLoading;
  final String? error;

  const DiscoveryState({
    this.filters = const ListingFilters(),
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  DiscoveryState copyWith({
    ListingFilters? filters,
    List<Listing>? results,
    bool? isLoading,
    String? error,
  }) {
    return DiscoveryState(
      filters: filters ?? this.filters,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier(this._repository) : super(const DiscoveryState()) {
    search();
  }

  final ListingRepository _repository;

  Future<void> search() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await _repository.search(state.filters);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: apiErrorMessage(e));
    }
  }

  void applyFilters(ListingFilters filters) {
    state = state.copyWith(filters: filters);
    search();
  }
}

final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
      return DiscoveryNotifier(ref.watch(listingRepositoryProvider));
    });
