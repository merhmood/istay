import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_shared/models/listing.dart';

export 'package:staynaija_shared/listings/listing_repository.dart';

class DiscoveryState {
  final ListingFilters filters;
  final List<Listing> results;
  final bool isLoading;
  final String? error;

  const DiscoveryState({this.filters = const ListingFilters(), this.results = const [], this.isLoading = false, this.error});

  DiscoveryState copyWith({ListingFilters? filters, List<Listing>? results, bool? isLoading, String? error}) {
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

final discoveryProvider = StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier(ref.watch(listingRepositoryProvider));
});
