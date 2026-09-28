import 'package:staynaija_shared/models/stay_type.dart';

class ListingPhoto {
  final String id;
  final String url;
  final int position;

  ListingPhoto({required this.id, required this.url, required this.position});

  factory ListingPhoto.fromJson(Map<String, dynamic> json) =>
      ListingPhoto(id: json['id'], url: json['url'], position: json['position'] ?? 0);
}

class Listing {
  final String id;
  final String hostId;
  final String title;
  final String description;
  final String city;
  final String neighborhoodLandmark;
  final double latitude;
  final double longitude;
  final String propertyType;
  final int bedrooms;
  final int bathrooms;
  final int maxGuests;
  /// Always a true per-night amount, regardless of the listing's stay type -
  /// see `PricingUnit`'s doc comment. Use [displayRate] / [displayUnitLabel]
  /// for anything shown to a host or guest, never this raw figure directly.
  final double nightlyRate;
  final double weeklyDiscountPercent;
  final double monthlyDiscountPercent;
  final double cleaningFee;

  /// Shortest stay this listing accepts, in nights. Enforced server-side at
  /// booking time, not just a UI hint - see `services/pricing.py`.
  final int minimumNights;

  /// Called out as its own field rather than folded into `amenities` because
  /// it changes what a guest expects to pay for separately, and is the one
  /// detail explicitly named in three of the ten stay-type descriptions.
  final bool breakfastIncluded;

  final List<String> amenities;
  final String? houseRules;
  final bool hasGenerator;
  final bool hasInverter;
  final bool has24hrElectricity;
  final bool isGatedEstate;
  final bool hasSecurityGuard;
  final bool hasCctv;
  final bool instantBook;
  final bool isPublished;
  final List<ListingPhoto> photos;

  Listing({
    required this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.city,
    required this.neighborhoodLandmark,
    required this.latitude,
    required this.longitude,
    required this.propertyType,
    required this.bedrooms,
    required this.bathrooms,
    required this.maxGuests,
    required this.nightlyRate,
    required this.weeklyDiscountPercent,
    required this.monthlyDiscountPercent,
    required this.cleaningFee,
    this.minimumNights = 1,
    this.breakfastIncluded = false,
    required this.amenities,
    required this.houseRules,
    required this.hasGenerator,
    required this.hasInverter,
    required this.has24hrElectricity,
    required this.isGatedEstate,
    required this.hasSecurityGuard,
    required this.hasCctv,
    required this.instantBook,
    required this.isPublished,
    required this.photos,
  });

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id'],
        hostId: json['host_id'],
        title: json['title'],
        description: json['description'],
        city: json['city'],
        neighborhoodLandmark: json['neighborhood_landmark'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        propertyType: json['property_type'],
        bedrooms: json['bedrooms'] ?? 1,
        bathrooms: json['bathrooms'] ?? 1,
        maxGuests: json['max_guests'] ?? 2,
        nightlyRate: (json['nightly_rate'] as num).toDouble(),
        weeklyDiscountPercent: (json['weekly_discount_percent'] as num?)?.toDouble() ?? 0,
        monthlyDiscountPercent: (json['monthly_discount_percent'] as num?)?.toDouble() ?? 0,
        cleaningFee: (json['cleaning_fee'] as num?)?.toDouble() ?? 0,
        minimumNights: json['minimum_nights'] ?? 1,
        breakfastIncluded: json['breakfast_included'] ?? false,
        amenities: List<String>.from(json['amenities'] ?? []),
        houseRules: json['house_rules'],
        hasGenerator: json['has_generator'] ?? false,
        hasInverter: json['has_inverter'] ?? false,
        has24hrElectricity: json['has_24hr_electricity'] ?? false,
        isGatedEstate: json['is_gated_estate'] ?? false,
        hasSecurityGuard: json['has_security_guard'] ?? false,
        hasCctv: json['has_cctv'] ?? false,
        instantBook: json['instant_book'] ?? false,
        isPublished: json['is_published'] ?? true,
        photos: (json['photos'] as List<dynamic>? ?? []).map((p) => ListingPhoto.fromJson(p)).toList(),
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'description': description,
        'city': city,
        'neighborhood_landmark': neighborhoodLandmark,
        'latitude': latitude,
        'longitude': longitude,
        'property_type': propertyType,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'max_guests': maxGuests,
        'nightly_rate': nightlyRate,
        'weekly_discount_percent': weeklyDiscountPercent,
        'monthly_discount_percent': monthlyDiscountPercent,
        'cleaning_fee': cleaningFee,
        'minimum_nights': minimumNights,
        'breakfast_included': breakfastIncluded,
        'amenities': amenities,
        'house_rules': houseRules,
        'has_generator': hasGenerator,
        'has_inverter': hasInverter,
        'has_24hr_electricity': has24hrElectricity,
        'is_gated_estate': isGatedEstate,
        'has_security_guard': hasSecurityGuard,
        'has_cctv': hasCctv,
        'instant_book': instantBook,
      };

  /// The pricing unit this listing's stay type is quoted in.
  PricingUnit get pricingUnit => pricingUnitFor(propertyType);

  /// [nightlyRate] converted into the unit a host/guest actually thinks in -
  /// e.g. a Long stay listing shows a monthly figure, not its nightly
  /// equivalent. Always derived from the stored nightly rate, never stored
  /// itself, so the two can never drift apart.
  double get displayRate => nightlyRate * pricingUnit.nightsPerUnit;

  /// "night" / "week" / "month", for building "₦X / \$displayUnitLabel".
  String get displayUnitLabel => pricingUnit.label;
}

class AvailabilityBlock {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final bool isBlocked;
  final double? overrideNightlyRate;

  AvailabilityBlock({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.isBlocked,
    required this.overrideNightlyRate,
  });

  factory AvailabilityBlock.fromJson(Map<String, dynamic> json) => AvailabilityBlock(
        id: json['id'],
        startDate: DateTime.parse(json['start_date']),
        endDate: DateTime.parse(json['end_date']),
        isBlocked: json['is_blocked'] ?? true,
        overrideNightlyRate: (json['override_nightly_rate'] as num?)?.toDouble(),
      );
}
