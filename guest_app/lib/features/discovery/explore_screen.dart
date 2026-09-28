import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/map_markers.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija/features/discovery/discovery_provider.dart';
import 'package:staynaija/features/discovery/services/directions_service.dart';
import 'package:staynaija_shared/core/location/location_service.dart';
import 'package:staynaija/features/discovery/services/recent_searches_service.dart';
import 'package:staynaija_shared/core/map/brand_tile_layer.dart';
import 'package:staynaija/features/discovery/search_screen.dart';
import 'package:staynaija/features/discovery/widgets/explore_result_tile.dart';
import 'package:staynaija/features/discovery/widgets/filter_sheet.dart';
import 'package:staynaija/features/discovery/widgets/get_there_sheet.dart';
import 'package:staynaija/features/discovery/widgets/route_info_card.dart';

const _nigeriaCentroid = LatLng(9.0820, 8.6753);

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _mapController = MapController();
  final _cityController = TextEditingController();
  final _locationService = LocationService();
  final _directionsService = DirectionsService();
  final _recentSearchesService = RecentSearchesService();

  LatLng? _myLocation;
  Listing? _selectedListing;
  RouteResult? _route;
  bool _isLoadingRoute = false;
  String? _routeError;
  bool _hasSearched = false;
  List<String> _recentSearches = [];
  List<NearbyArea>? _nearbyAreas;
  bool _isLoadingNearbyPlaces = false;
  bool _locationResolved = false;
  bool _hasCenteredOnResults = false;
  bool _isMapReady = false;
  LatLng? _pendingCameraTarget;
  /// Live height of the bottom sheet as a fraction of the screen, so the
  /// my-location button can sit above it instead of under it. Null until the
  /// sheet reports its first extent.
  double? _sheetExtent;

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
    _loadRecentSearches();
  }

  /// This screen is built eagerly inside the shell's IndexedStack, so a camera
  /// move can be requested (e.g. once GPS resolves) before FlutterMap has
  /// initialised - MapController silently drops those. Queue the target and
  /// apply it from onMapReady instead.
  void _moveCamera(LatLng target, {double zoom = 12}) {
    if (!_isMapReady) {
      _pendingCameraTarget = target;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _mapController.move(target, zoom));
  }

  /// Suggestions come from places that actually have listings, not from
  /// OpenStreetMap place names. Those were real places, but most had no stays,
  /// so tapping a chip dead-ended on an empty search.
  Future<void> _loadNearbyPlaces() async {
    final origin = _myLocation;
    if (origin == null) return;
    setState(() => _isLoadingNearbyPlaces = true);
    try {
      final areas = await ref.read(listingRepositoryProvider).areasNearby(
            latitude: origin.latitude,
            longitude: origin.longitude,
          );
      if (mounted) setState(() => _nearbyAreas = areas);
    } catch (_) {
      // Leave null: the panel then says it could not load rather than showing
      // places that might have nothing in them.
    } finally {
      if (mounted) setState(() => _isLoadingNearbyPlaces = false);
    }
  }

  Future<void> _loadRecentSearches() async {
    final recent = await _recentSearchesService.get();
    if (mounted) setState(() => _recentSearches = recent);
  }

  Future<void> _openSearchScreen() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          nearbyPlaceNames: [for (final area in _nearbyAreas ?? const <NearbyArea>[]) area.name],
        ),
      ),
    );
    if (selected != null && selected.isNotEmpty) _searchCity(selected);
  }

  void _searchCity(String city) {
    _clearSelection();
    setState(() => _hasSearched = true);
    ref.read(discoveryProvider.notifier).applyFilters(ref.read(discoveryProvider).filters.copyWith(city: city));
    _recentSearchesService.record(city);
    _loadRecentSearches();
    _cityController.text = city;
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadMyLocation() async {
    // A cold GPS fix can take many seconds, during which the suggestions panel
    // would show the static popular-cities fallback. The cached last-known fix
    // comes back immediately and is accurate enough to pick the right town, so
    // use it first and refine once the live fix lands.
    final cached = await _locationService.getLastKnownPosition();
    if (mounted && cached != null) {
      _applyLocation(LatLng(cached.latitude, cached.longitude));
    }

    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      if (position != null) _applyLocation(LatLng(position.latitude, position.longitude));
    } finally {
      // Marks the end of the location attempt either way - the suggestions panel
      // waits on this before it is willing to fall back to the static city list.
      if (mounted) setState(() => _locationResolved = true);
    }
  }

  void _applyLocation(LatLng location) {
    final previous = _myLocation;
    setState(() => _myLocation = location);

    // GPS typically resolves slower than the listings search, so by the time we
    // get here the map may already be centered on a fallback (first search
    // result). The real device location always takes priority once it's ready.
    _hasCenteredOnResults = true;
    _moveCamera(location);

    // Only re-query Overpass when we've actually moved somewhere new - refining
    // a cached fix by a few hundred metres won't change the nearby towns.
    const distance = Distance();
    if (previous == null || distance(previous, location) > 3000 || _nearbyAreas == null) {
      _loadNearbyPlaces();
    }
  }

  /// Picking a listing just shows its details and centres it - routing is
  /// opt-in via the card's directions button.
  void _selectListing(Listing listing) {
    setState(() {
      _selectedListing = listing;
      _route = null;
      _routeError = null;
      _isLoadingRoute = false;
    });
    _moveCamera(LatLng(listing.latitude, listing.longitude), zoom: 14);
    // Weaker than opening the listing - a map tap is often just curiosity about
    // a pin - but it says something about where someone wants to be, which is
    // exactly what the feed is trying to learn.
    ref
        .read(listingRepositoryProvider)
        .recordInteraction(listing.id, InteractionKind.mapView);
  }

  /// Offers the ride and maps apps that can actually take the guest there.
  void _openGetThereSheet() {
    final listing = _selectedListing;
    if (listing == null) return;
    showGetThereSheet(
      context,
      listing: listing,
      onHandoff: () => ref
          .read(listingRepositoryProvider)
          .recordInteraction(listing.id, InteractionKind.directions),
    );
  }

  Future<void> _showDirections() async {
    final listing = _selectedListing;
    if (listing == null) return;

    final destination = LatLng(listing.latitude, listing.longitude);
    if (_myLocation == null) {
      setState(() => _routeError = 'Turn on location to see directions.');
      return;
    }

    setState(() {
      _route = null;
      _routeError = null;
      _isLoadingRoute = true;
    });

    _fitBounds([_myLocation!, destination]);
    try {
      final route = await _directionsService.getRoute(from: _myLocation!, to: destination);
      if (!mounted) return;
      setState(() {
        _route = route;
        _isLoadingRoute = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeError = 'Could not load a route right now.';
        _isLoadingRoute = false;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedListing = null;
      _route = null;
      _routeError = null;
    });
  }

  void _fitBounds(List<LatLng> points) {
    if (points.length < 2) {
      _mapController.move(points.first, 14);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(60, 120, 60, 260)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final results = state.results;
    final initialCenter = results.isNotEmpty ? LatLng(results.first.latitude, results.first.longitude) : (_myLocation ?? _nigeriaCentroid);

    // `initialZoom` on FlutterMap only applies to the very first frame, which
    // happens before the listing search resolves (results still empty at that
    // point) - so without this, the map stays at the zoomed-out country/state
    // view forever. Explicitly zoom to city level the first time results land.
    ref.listen(discoveryProvider, (previous, next) {
      if (!_hasCenteredOnResults && next.results.isNotEmpty) {
        _hasCenteredOnResults = true;
        _moveCamera(_myLocation ?? LatLng(next.results.first.latitude, next.results.first.longitude));
      }
    });

    return Scaffold(
      // The map fills the screen, so let it keep its full height when the
      // keyboard opens; the bottom sheet is lifted above the keyboard manually
      // via viewInsets padding below instead of squashing the whole map.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: results.isNotEmpty ? 12 : 5.5,
              onMapReady: () {
                _isMapReady = true;
                final target = _pendingCameraTarget ?? _myLocation;
                if (target != null) {
                  _pendingCameraTarget = null;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _mapController.move(target, 12));
                }
              },
            ),
            children: [
              // Fully-labelled tiles, desaturated to the app's monochrome so
              // the price markers are the only colour on screen.
              const BrandTileLayer(
                userAgentPackageName: 'com.staynaija.mobile',
                // Fetch fewer off-screen tiles; the cache makes re-panning to
                // them cheap anyway.
                panBuffer: 0,
                keepBuffer: 2,
              ),
              if (_route != null)
                PolylineLayer(
                  polylines: [Polyline(points: _route!.points, strokeWidth: 4, color: AppColors.primary)],
                ),
              MarkerLayer(
                markers: [
                  for (final listing in results)
                    Marker(
                      point: LatLng(listing.latitude, listing.longitude),
                      width: 130,
                      height: 56,
                      child: GestureDetector(
                        onTap: () => _selectListing(listing),
                        child: _PriceMarker(listing: listing, selected: _selectedListing?.id == listing.id),
                      ),
                    ),
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 28,
                      height: 28,
                      child: const MyLocationDot(size: 28),
                    ),
                ],
              ),
              // Attribution is required by OpenStreetMap's terms; the collapsed
              // "i" button keeps it out of the way.
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
                  if (TileSource.hasKey) TextSourceAttribution(TileSource.attribution, onTap: () {}),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
                    child: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: Icon(LucideIcons.slidersHorizontal, color: Colors.white),
                      onPressed: () async {
                        final updated = await showModalBottomSheet<ListingFilters>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => FilterSheet(initialFilters: state.filters),
                        );
                        if (updated != null) {
                          _clearSelection();
                          setState(() => _hasSearched = true);
                          ref.read(discoveryProvider.notifier).applyFilters(updated);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                      ),
                      // Read-only: tapping opens the dedicated search screen
                      // rather than raising a keyboard over the map/drawer.
                      child: TextField(
                        controller: _cityController,
                        readOnly: true,
                        onTap: _openSearchScreen,
                        decoration: InputDecoration(
                          // Kept short: the row now also carries the filter
                          // and saved buttons.
                          hintText: 'Search city, state, or stay type',
                          prefixIcon: Icon(LucideIcons.search, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                    ),
                    child: IconButton(
                      icon: const HeroIcon(HeroIcons.heart, style: HeroIconStyle.outline),
                      tooltip: 'Saved',
                      onPressed: () => context.push('/saved'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Only while the suggestions/results sheet is up. With a listing
          // selected the button is stacked directly above the details card
          // instead, since that card changes height when directions load.
          if (_selectedListing == null)
            Positioned(
              right: 16,
              bottom: _locateButtonOffset(context),
              child: _locateButton('my-location-sheet'),
            ),
          if (state.isLoading)
            const Positioned(top: 80, left: 0, right: 0, child: Center(child: CircularProgressIndicator())),
          Padding(
            // Lift the sheet/card clear of the soft keyboard while searching.
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Align(
            alignment: Alignment.bottomCenter,
            child: _selectedListing != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 10),
                        child: _locateButton('my-location-card'),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: RouteInfoCard(
                          listing: _selectedListing!,
                          route: _route,
                          isLoadingRoute: _isLoadingRoute,
                          routeError: _routeError,
                          onBack: _clearSelection,
                          onViewListing: () => context.push('/listing/${_selectedListing!.id}'),
                          onShowDirections: _showDirections,
                          onGetThere: _openGetThereSheet,
                        ),
                      ),
                    ],
                  )
                : NotificationListener<DraggableScrollableNotification>(
                    onNotification: (notification) {
                      if (_sheetExtent != notification.extent) {
                        // Fired mid-layout while dragging, so defer the rebuild.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _sheetExtent = notification.extent);
                        });
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                    initialChildSize: _hasSearched ? 0.32 : 0.4,
                    minChildSize: 0.14,
                    maxChildSize: 0.85,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
                        ),
                        child: !_hasSearched
                            ? _suggestionsPanel(scrollController)
                            : results.isEmpty
                                ? _emptyState(state, scrollController)
                                : ListView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                                    children: [
                                      _dragHandle(),
                                      Text('${results.length} stays', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 12),
                                      for (final listing in results) ExploreResultTile(listing: listing, onTap: () => _selectListing(listing)),
                                    ],
                                  ),
                      );
                    },
                  ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locateButton(String heroTag) => FloatingActionButton.small(
        heroTag: heroTag,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        onPressed: () async {
          await _loadMyLocation();
          if (_myLocation != null) _moveCamera(_myLocation!, zoom: 14);
        },
        child: Icon(LucideIcons.locate),
      );

  /// Keeps the my-location button clear of the bottom sheet. The sheet is sized
  /// as a fraction of the screen, so a fixed offset works on some devices and is
  /// swallowed on others - track its real extent instead. (The details-card case
  /// doesn't come through here: that button is stacked above the card directly,
  /// because the card changes height once a route loads.)
  double _locateButtonOffset(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final extent = _sheetExtent ?? (_hasSearched ? 0.32 : 0.4);
    // Cap it so dragging the sheet to full height doesn't push the button up
    // behind the search bar.
    return (screenHeight * extent + 12).clamp(90.0, screenHeight * 0.55);
  }

  Widget _dragHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _suggestionsPanel(ScrollController scrollController) {
    // Every suggestion here is a place with listings, so a chip can never lead
    // to an empty search. Nothing renders until the lookup resolves: showing a
    // guess early meant places appeared and then swapped out, which read as a
    // wrong answer rather than a pending one.
    final areas = _nearbyAreas;
    final hasAreas = areas != null && areas.isNotEmpty;
    final isResolving = !_locationResolved || _isLoadingNearbyPlaces || (_myLocation != null && areas == null);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        _dragHandle(),
        if (_recentSearches.isNotEmpty) ...[
          Text('Recent searches', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final city in _recentSearches)
                _SuggestionChip(icon: LucideIcons.clock, label: city, onTap: () => _searchCity(city)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (isResolving)
          Row(
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Finding stays near you...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          )
        else if (!hasAreas)
          // Genuinely nowhere to stay nearby. Said plainly, with the way out,
          // rather than offering places that would return nothing.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.mapPinOff, size: 17, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text('No stays near you yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'There are no listings within 150km of where you are. Try searching another city.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _openSearchScreen,
                  icon: Icon(LucideIcons.search, size: 16),
                  label: const Text('Search a city', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          )
        else ...[
          const Text('Stays near you', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final area in areas)
                _SuggestionChip(
                  icon: LucideIcons.mapPin,
                  // Distance is what makes a neighbourhood chip worth tapping -
                  // "Jabi · 4.5 km" tells a guest something, where the old
                  // city-level "Abuja · 9" told someone already in Abuja
                  // nothing at all. The count is only shown when there is more
                  // than one, since "· 1 stay" is noise on most chips.
                  label: area.listingCount > 1
                      ? '${area.name} · ${area.listingCount} stays · ${area.distanceLabel}'
                      : '${area.name} · ${area.distanceLabel}',
                  onTap: () => _searchCity(area.name),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _emptyState(DiscoveryState state, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Text(
            state.error != null ? 'Could not load listings.\n${state.error}' : 'No listings match your search yet.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Price pill shown on the map for each result.
class _PriceMarker extends StatelessWidget {
  const _PriceMarker({required this.listing, required this.selected});

  final Listing listing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Text(
            formatNaira(listing.nightlyRate),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        MapPin(
          icon: LucideIcons.house,
          size: 22,
          color: selected ? AppColors.primary : AppColors.primary,
        ),
      ],
    );
  }
}
