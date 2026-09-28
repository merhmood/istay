"""The fixed set of stay types a listing can be.

Free text here would mean the same kind of place gets spelled three different
ways across three different hosts ("self-contain", "Self Contain", "self con"),
which breaks both the guest-facing filter and the recommendation model's
property-type affinity - a filter chip only works if every host who meant the
same thing picked the same value.

This list is the single source of truth on the backend; the Dart client keeps
its own copy in `staynaija_shared/lib/models/stay_type.dart` since the two
apps have no shared package to pull it from. Keep the two in sync - each file
says so at the top.
"""
from __future__ import annotations

from dataclasses import dataclass


#: The unit a host prices and thinks in for a given stay type. Every listing's
#: `nightly_rate` column always stores a true per-night amount (see the model)
#: - this is a display/input concern, converted at the client boundary, never
#: used to change how a booking's price is computed.
NIGHTLY = "nightly"
WEEKLY = "weekly"
MONTHLY = "monthly"

#: How many nights one unit of that pricing period spans, for converting a
#: host's natural-unit figure to/from the stored nightly-equivalent rate.
#: 30 rather than a calendar month's actual day count, matching how Nigerian
#: shortlet/rent pricing is conventionally quoted ("per month" meaning a flat
#: 30-day period, not the 28-31 the calendar actually gives you).
UNIT_NIGHTS: dict[str, int] = {NIGHTLY: 1, WEEKLY: 7, MONTHLY: 30}


@dataclass(frozen=True)
class StayType:
    slug: str
    label: str
    description: str
    pricing_unit: str = NIGHTLY
    #: Suggested floor for a new listing of this type, not enforced by data
    #: alone - a host can always raise or lower it on the create/edit form.
    #: Existing to stop the obviously-wrong default (a Long stay listing
    #: booking-able for one night) rather than to reflect real research on
    #: typical minimums.
    default_minimum_nights: int = 1


STAY_TYPES: tuple[StayType, ...] = (
    StayType("hotel_stay", "Hotel stay", "Short-term accommodation in a hotel."),
    StayType(
        "shortlet_apartment",
        "Shortlet / serviced apartment",
        "Apartment rented for a few days or weeks, often furnished.",
    ),
    StayType(
        "long_stay",
        "Long stay",
        "Accommodation for several weeks or months.",
        pricing_unit=MONTHLY,
        default_minimum_nights=30,
    ),
    StayType(
        "extended_stay",
        "Extended stay",
        "Hotel/apartment designed for longer periods, usually with kitchen/laundry facilities.",
        pricing_unit=WEEKLY,
        default_minimum_nights=7,
    ),
    StayType("hostel_stay", "Hostel stay", "Budget accommodation with shared rooms/facilities."),
    StayType(
        "resort_stay",
        "Resort stay",
        "Accommodation with leisure facilities such as pools, restaurants and activities.",
    ),
    StayType("guesthouse_bnb", "Guesthouse/B&B", "Smaller accommodation, often including breakfast."),
    StayType(
        "vacation_rental",
        "Vacation rental",
        "Entire house, apartment, villa, etc., rented temporarily.",
        default_minimum_nights=2,
    ),
    StayType("homestay", "Homestay", "Staying in someone's home, usually with the host."),
    StayType("lodge_stay", "Lodge stay", "Common for nature, safari, or remote locations."),
)

STAY_TYPE_SLUGS: frozenset[str] = frozenset(t.slug for t in STAY_TYPES)
STAY_TYPE_LABELS: dict[str, str] = {t.slug: t.label for t in STAY_TYPES}
STAY_TYPE_BY_SLUG: dict[str, StayType] = {t.slug: t for t in STAY_TYPES}

# Demo/legacy listings were seeded before this taxonomy existed, using loose
# words like "apartment" or "house". Mapped to their closest real type so old
# rows display and filter sensibly rather than falling through as "unknown".
LEGACY_ALIASES: dict[str, str] = {
    "apartment": "shortlet_apartment",
    "studio": "shortlet_apartment",
    "self-contain": "shortlet_apartment",
    "duplex": "vacation_rental",
    "house": "vacation_rental",
}


def normalize_stay_type(value: str) -> str:
    """Best-effort canonical slug for a possibly-legacy value.

    Falls back to the value itself so an unrecognised string still round-trips
    rather than being silently dropped.
    """
    if value in STAY_TYPE_SLUGS:
        return value
    return LEGACY_ALIASES.get(value, value)
