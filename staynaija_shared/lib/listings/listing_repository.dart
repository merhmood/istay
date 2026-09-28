import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/storage/secure_storage.dart';
import 'package:staynaija_shared/models/listing.dart';

final listingRepositoryProvider = Provider((ref) => ListingRepository());

class ListingFilters {
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final int? maxGuests;
  final bool? hasGenerator;
  final bool? hasInverter;
  final bool? has24hrElectricity;
  final bool? isGatedEstate;
  final bool? hasSecurityGuard;
  final bool? hasCctv;
  final List<String> amenities;

  /// A stay-type slug from `models/stay_type.dart`, or null for "any type".
  final String? propertyType;

  const ListingFilters({
    this.city,
    this.minPrice,
    this.maxPrice,
    this.maxGuests,
    this.hasGenerator,
    this.hasInverter,
    this.has24hrElectricity,
    this.isGatedEstate,
    this.hasSecurityGuard,
    this.hasCctv,
    this.amenities = const [],
    this.propertyType,
  });

  ListingFilters copyWith({
    String? city,
    double? minPrice,
    double? maxPrice,
    int? maxGuests,
    bool? hasGenerator,
    bool? hasInverter,
    bool? has24hrElectricity,
    bool? isGatedEstate,
    bool? hasSecurityGuard,
    bool? hasCctv,
    List<String>? amenities,
    String? propertyType,
    // copyWith's usual `??` pattern can only ever set propertyType, never
    // clear it back to "any type" - tapping a selected chip a second time
    // needs exactly that, so this is the one field with an explicit escape
    // hatch rather than adding that ambiguity to every field here.
    bool clearPropertyType = false,
  }) {
    return ListingFilters(
      city: city ?? this.city,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      maxGuests: maxGuests ?? this.maxGuests,
      hasGenerator: hasGenerator ?? this.hasGenerator,
      hasInverter: hasInverter ?? this.hasInverter,
      has24hrElectricity: has24hrElectricity ?? this.has24hrElectricity,
      isGatedEstate: isGatedEstate ?? this.isGatedEstate,
      hasSecurityGuard: hasSecurityGuard ?? this.hasSecurityGuard,
      hasCctv: hasCctv ?? this.hasCctv,
      amenities: amenities ?? this.amenities,
      propertyType: clearPropertyType ? null : (propertyType ?? this.propertyType),
    );
  }

  Map<String, dynamic> toQuery() => {
        if (city != null && city!.isNotEmpty) 'city': city,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (maxGuests != null) 'max_guests': maxGuests,
        if (hasGenerator == true) 'has_generator': true,
        if (hasInverter == true) 'has_inverter': true,
        if (has24hrElectricity == true) 'has_24hr_electricity': true,
        if (isGatedEstate == true) 'is_gated_estate': true,
        if (hasSecurityGuard == true) 'has_security_guard': true,
        if (hasCctv == true) 'has_cctv': true,
        if (amenities.isNotEmpty) 'amenities': amenities,
        if (propertyType != null) 'property_type': propertyType,
      };
}

/// A place with stays available, as shown in Explore's suggestion chips.
class NearbyArea {
  /// The neighbourhood, e.g. "Jabi" or "Lekki" - not the city. Someone standing
  /// in Abuja learns nothing from being told there are stays in Abuja.
  final String name;

  /// The city the area belongs to, for disambiguating a bare neighbourhood name.
  final String city;
  final int listingCount;
  final double distanceKm;

  NearbyArea({
    required this.name,
    required this.city,
    required this.listingCount,
    required this.distanceKm,
  });

  factory NearbyArea.fromJson(Map<String, dynamic> json) => NearbyArea(
        name: json['name'],
        city: json['city'] ?? '',
        listingCount: json['listing_count'] ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      );

  /// "4.5 km" / "800 m" - below a kilometre, metres read as far more precise.
  String get distanceLabel =>
      distanceKm < 1 ? '${(distanceKm * 1000).round()} m' : '${distanceKm.toStringAsFixed(1)} km';
}

class ListingRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<List<Listing>> search(ListingFilters filters) async {
    final response = await _dio.get('/listings', queryParameters: filters.toQuery());
    return (response.data as List).map((json) => Listing.fromJson(json)).toList();
  }

  Future<Listing> getById(String id) async {
    final response = await _dio.get('/listings/$id');
    return Listing.fromJson(response.data);
  }

  /// Places near a point that actually have stays, nearest first. Unlike
  /// OpenStreetMap place names, every entry here is guaranteed to return
  /// results when tapped.
  Future<List<NearbyArea>> areasNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 150,
  }) async {
    final response = await _dio.get('/listings/areas-nearby', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
    });
    return [for (final item in response.data as List) NearbyArea.fromJson(item)];
  }

  Future<List<Listing>> myListings() async {
    final response = await _dio.get('/listings/mine');
    return (response.data as List).map((json) => Listing.fromJson(json)).toList();
  }

  Future<Listing> create(Listing listing) async {
    final response = await _dio.post('/listings', data: listing.toCreateJson());
    return Listing.fromJson(response.data);
  }

  Future<Listing> update(String id, Map<String, dynamic> changes) async {
    final response = await _dio.patch('/listings/$id', data: changes);
    return Listing.fromJson(response.data);
  }

  Future<void> delete(String id) => _dio.delete('/listings/$id');

  Future<ListingPhoto> uploadPhoto(String listingId, File file) async {
    final formData = FormData.fromMap({'file': await MultipartFile.fromFile(file.path)});
    final response = await _dio.post('/listings/$listingId/photos', data: formData);
    return ListingPhoto.fromJson(response.data);
  }

  Future<List<AvailabilityBlock>> getAvailability(String listingId) async {
    final response = await _dio.get('/listings/$listingId/availability');
    return (response.data as List).map((json) => AvailabilityBlock.fromJson(json)).toList();
  }

  Future<AvailabilityBlock> blockDates({
    required String listingId,
    required DateTime start,
    required DateTime end,
    double? overrideNightlyRate,
  }) async {
    final response = await _dio.post('/listings/$listingId/availability', data: {
      'start_date': start.toIso8601String().split('T').first,
      'end_date': end.toIso8601String().split('T').first,
      'is_blocked': true,
      'override_nightly_rate': overrideNightlyRate,
    });
    return AvailabilityBlock.fromJson(response.data);
  }

  Future<void> deleteAvailabilityBlock(String listingId, String blockId) =>
      _dio.delete('/listings/$listingId/availability/$blockId');

  /// A heuristic "recommended for you" feed (see the backend's docstring on
  /// GET /listings/recommended) - not a trained ML model.
  ///
  /// `latitude`/`longitude` are optional - the feed still works signed out or
  /// with location denied, it just can't favour nearby places without them.
  Future<List<Listing>> getRecommended({int limit = 10, double? latitude, double? longitude}) async {
    final response = await _dio.get(
      '/listings/recommended',
      queryParameters: {
        'limit': limit,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    return (response.data as List).map((json) => Listing.fromJson(json)).toList();
  }

  /// Reports a browsing signal that feeds the recommendation feed.
  ///
  /// Fire-and-forget by design. This is telemetry attached to something the
  /// person is already doing - opening a listing, tapping a map pin, calling a
  /// Bolt - and none of those should ever stall or fail because a background
  /// request did. Failures are swallowed on purpose.
  Future<void> recordInteraction(String listingId, InteractionKind kind) async {
    try {
      await _dio.post(
        '/listings/$listingId/interactions',
        data: {
          'kind': kind.wireName,
          // Ignored by the server when the request is authenticated.
          'anonymous_id': await SecureStorage.deviceId(),
        },
      );
    } catch (_) {
      // Losing a signal is acceptable; interrupting the guest is not.
    }
  }

  /// Views, taps, directions and bookings across every listing this host
  /// owns - the same browsing signals [recordInteraction] sends turn out to
  /// be exactly what a host wants to know too: how many people looked, and
  /// how many of them actually booked.
  Future<HostAnalytics> getAnalytics() async {
    final response = await _dio.get('/listings/analytics');
    return HostAnalytics.fromJson(response.data);
  }
}

/// One listing's performance, within [HostAnalytics.listings].
class ListingAnalytics {
  final String listingId;
  final String title;
  final int views;
  final int mapTaps;
  final int directions;
  final int bookings;
  final double revenue;

  ListingAnalytics({
    required this.listingId,
    required this.title,
    required this.views,
    required this.mapTaps,
    required this.directions,
    required this.bookings,
    required this.revenue,
  });

  factory ListingAnalytics.fromJson(Map<String, dynamic> json) => ListingAnalytics(
        listingId: json['listing_id'],
        title: json['title'],
        views: json['views'] ?? 0,
        mapTaps: json['map_taps'] ?? 0,
        directions: json['directions'] ?? 0,
        bookings: json['bookings'] ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

/// One month's bookings and revenue, across all of a host's listings.
class MonthlyTrendPoint {
  /// "2026-09".
  final String month;
  final int bookings;
  final double revenue;

  MonthlyTrendPoint({required this.month, required this.bookings, required this.revenue});

  factory MonthlyTrendPoint.fromJson(Map<String, dynamic> json) => MonthlyTrendPoint(
        month: json['month'],
        bookings: json['bookings'] ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );

  /// "Sep" - for a chart axis label, where "2026-09" would be too wide.
  String get shortLabel {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final parts = month.split('-');
    final index = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    return names[(index - 1).clamp(0, 11)];
  }
}

class HostAnalytics {
  final int totalViews;
  final int totalMapTaps;
  final int totalDirections;
  final int totalBookings;
  final double totalRevenue;

  /// Bookings per view - null when there are no views yet, since a rate over
  /// zero is meaningless rather than zero.
  final double? conversionRate;
  final List<ListingAnalytics> listings;

  /// Always 6 points, oldest first, even for months with nothing in them.
  final List<MonthlyTrendPoint> monthlyTrend;

  HostAnalytics({
    required this.totalViews,
    required this.totalMapTaps,
    required this.totalDirections,
    required this.totalBookings,
    required this.totalRevenue,
    required this.conversionRate,
    required this.listings,
    required this.monthlyTrend,
  });

  factory HostAnalytics.fromJson(Map<String, dynamic> json) => HostAnalytics(
        totalViews: json['total_views'] ?? 0,
        totalMapTaps: json['total_map_taps'] ?? 0,
        totalDirections: json['total_directions'] ?? 0,
        totalBookings: json['total_bookings'] ?? 0,
        totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
        conversionRate: (json['conversion_rate'] as num?)?.toDouble(),
        listings: (json['listings'] as List<dynamic>? ?? [])
            .map((j) => ListingAnalytics.fromJson(j))
            .toList(),
        monthlyTrend: (json['monthly_trend'] as List<dynamic>? ?? [])
            .map((j) => MonthlyTrendPoint.fromJson(j))
            .toList(),
      );
}

/// The browsing signals the recommendation model learns from.
///
/// Bookings and favourites are recorded elsewhere, as a side effect of those
/// actions; these are the lighter ones that have to be reported explicitly.
enum InteractionKind {
  /// Opened the listing detail screen.
  view('view'),

  /// Tapped the listing's marker on the Explore map.
  mapView('map_view'),

  /// Asked how to get there - opened Bolt, Uber, inDrive or Google Maps. The
  /// strongest of the three: nobody calls a ride to somewhere they are idly
  /// browsing.
  directions('directions');

  const InteractionKind(this.wireName);

  final String wireName;
}
