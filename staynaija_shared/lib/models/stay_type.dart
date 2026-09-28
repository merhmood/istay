/// The unit a host prices and thinks in for a given stay type.
///
/// `Listing.nightlyRate` always stores a true per-night amount, regardless of
/// this - see the field's own doc comment. This only governs what number the
/// host is shown/enters and what guests are shown; the host app converts at
/// the form boundary via [PricingUnit.nightsPerUnit] before the figure ever
/// reaches the API, and converts back the same way when loading a listing for
/// editing.
enum PricingUnit {
  nightly('night', 1),
  weekly('week', 7),
  monthly('month', 30);

  const PricingUnit(this.label, this.nightsPerUnit);

  /// "night" / "week" / "month" - for building copy like "₦X / \$label".
  final String label;

  /// How many nights one unit spans. 30 for a month rather than the calendar's
  /// actual 28-31, matching how Nigerian rent/shortlet pricing is
  /// conventionally quoted - "per month" means a flat 30-day period.
  final int nightsPerUnit;
}

/// The fixed set of stay types a listing can be.
///
/// Mirrors `backend/app/core/stay_types.py` exactly - this is the client-side
/// copy of that single source of truth. There is no shared package between
/// the Python backend and this Dart client, so the two lists are kept in sync
/// by hand; if you add or rename a type, update both files.
class StayType {
  const StayType({
    required this.slug,
    required this.label,
    required this.description,
    this.pricingUnit = PricingUnit.nightly,
    this.defaultMinimumNights = 1,
  });

  /// The value stored on `Listing.propertyType` and sent to the API.
  final String slug;
  final String label;
  final String description;
  final PricingUnit pricingUnit;

  /// Suggested floor for a *new* listing of this type - offered as the
  /// starting value on the create form, never silently imposed on an
  /// existing listing's own stored `minimumNights`.
  final int defaultMinimumNights;
}

const List<StayType> stayTypes = [
  StayType(slug: 'hotel_stay', label: 'Hotel stay', description: 'Short-term accommodation in a hotel.'),
  StayType(
    slug: 'shortlet_apartment',
    label: 'Shortlet / serviced apartment',
    description: 'Apartment rented for a few days or weeks, often furnished.',
  ),
  StayType(
    slug: 'long_stay',
    label: 'Long stay',
    description: 'Accommodation for several weeks or months.',
    pricingUnit: PricingUnit.monthly,
    defaultMinimumNights: 30,
  ),
  StayType(
    slug: 'extended_stay',
    label: 'Extended stay',
    description: 'Hotel/apartment designed for longer periods, usually with kitchen/laundry facilities.',
    pricingUnit: PricingUnit.weekly,
    defaultMinimumNights: 7,
  ),
  StayType(
    slug: 'hostel_stay',
    label: 'Hostel stay',
    description: 'Budget accommodation with shared rooms/facilities.',
  ),
  StayType(
    slug: 'resort_stay',
    label: 'Resort stay',
    description: 'Accommodation with leisure facilities such as pools, restaurants and activities.',
  ),
  StayType(
    slug: 'guesthouse_bnb',
    label: 'Guesthouse/B&B',
    description: 'Smaller accommodation, often including breakfast.',
  ),
  StayType(
    slug: 'vacation_rental',
    label: 'Vacation rental',
    description: 'Entire house, apartment, villa, etc., rented temporarily.',
    defaultMinimumNights: 2,
  ),
  StayType(slug: 'homestay', label: 'Homestay', description: "Staying in someone's home, usually with the host."),
  StayType(
    slug: 'lodge_stay',
    label: 'Lodge stay',
    description: 'Common for nature, safari, or remote locations.',
  ),
];

/// Listings seeded or edited before this taxonomy existed hold looser words
/// like "apartment" or "house". Mapped to the closest real type so old rows
/// still show a sensible label instead of a raw, unrecognised slug.
const Map<String, String> _legacyStayTypeAliases = {
  'apartment': 'shortlet_apartment',
  'studio': 'shortlet_apartment',
  'self-contain': 'shortlet_apartment',
  'duplex': 'vacation_rental',
  'house': 'vacation_rental',
};

/// The display label for a slug, falling back through the legacy aliases and
/// finally to a capitalised version of whatever was actually stored - so an
/// unrecognised value still reads as words rather than breaking the screen.
String stayTypeLabel(String slug) {
  for (final type in stayTypes) {
    if (type.slug == slug) return type.label;
  }
  final alias = _legacyStayTypeAliases[slug];
  if (alias != null) return stayTypeLabel(alias);
  if (slug.isEmpty) return 'Stay';
  return '${slug[0].toUpperCase()}${slug.substring(1).replaceAll('_', ' ')}';
}

/// A canonical slug for a possibly-legacy or unrecognised value, guaranteed to
/// be one of [stayTypes] - unlike [stayTypeLabel], which is happy to describe
/// something outside the list, this is for places (like a dropdown) that need
/// an actual match to select. Falls back to the first stay type rather than
/// the raw value, since returning something not in the list would just move
/// the crash one call site later.
String normalizeStayTypeSlug(String slug) {
  if (stayTypes.any((t) => t.slug == slug)) return slug;
  final alias = _legacyStayTypeAliases[slug];
  if (alias != null) return alias;
  return stayTypes.first.slug;
}

/// The [PricingUnit] a listing's stay type is priced in, given its raw
/// (possibly legacy) `propertyType` slug.
PricingUnit pricingUnitFor(String propertyTypeSlug) {
  final normalized = normalizeStayTypeSlug(propertyTypeSlug);
  return stayTypes.firstWhere((t) => t.slug == normalized, orElse: () => stayTypes.first).pricingUnit;
}

/// A short, guest-facing callout for what makes this stay type worth calling
/// out on the listing page - null for types (hotel stay, shortlet apartment,
/// vacation rental) where the standard photos/amenities/facts sections
/// already say everything that matters, so an extra banner would be noise.
String? stayTypeGuestNote(String propertyTypeSlug) {
  switch (normalizeStayTypeSlug(propertyTypeSlug)) {
    case 'hostel_stay':
      return 'Budget stay with shared facilities - you may share the room or common areas with other guests.';
    case 'resort_stay':
      return 'Resort stay - expect leisure facilities like pools, restaurants or activities on site.';
    case 'guesthouse_bnb':
      return "Guesthouse stay - usually includes the host's presence and breakfast.";
    case 'homestay':
      return "You'll be staying in the host's own home, usually with them present.";
    case 'long_stay':
      return 'Long stay - priced and billed monthly, meant for guests staying weeks or months at a time.';
    case 'extended_stay':
      return 'Extended stay - priced and billed weekly, typically with kitchen and laundry facilities.';
    case 'lodge_stay':
      return 'Lodge stay - common for nature, safari or remote locations; amenities may be simpler than a city stay.';
    default:
      return null;
  }
}
