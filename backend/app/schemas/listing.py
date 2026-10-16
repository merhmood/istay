import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.stay_types import STAY_TYPE_SLUGS

# Pydantic's Literal needs a fixed tuple of string literals, not an iterable
# built at runtime - so the choices are spelled out here, with STAY_TYPE_SLUGS
# asserted equal in a test rather than generated, to keep the type checker able
# to see the actual values.
StayTypeSlug = Literal[
    "hotel_stay",
    "shortlet_apartment",
    "long_stay",
    "extended_stay",
    "hostel_stay",
    "resort_stay",
    "guesthouse_bnb",
    "vacation_rental",
    "homestay",
    "lodge_stay",
]
assert set(StayTypeSlug.__args__) == STAY_TYPE_SLUGS, "StayTypeSlug has drifted from STAY_TYPES"


class ListingPhotoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    url: str
    position: int


class ListingBase(BaseModel):
    title: str
    description: str
    city: str
    neighborhood_landmark: str
    latitude: float
    longitude: float
    # Loose here deliberately: this base is also `ListingOut`'s parent, and a
    # listing seeded before this taxonomy existed (or edited directly in the
    # database) can hold a value outside the fixed set. A strict Literal here
    # would make GET /listings 500 the moment one such row was fetched.
    # `ListingCreate` below narrows this back down to `StayTypeSlug` for writes,
    # which is where validation actually needs to bite.
    property_type: str
    bedrooms: int = 1
    bathrooms: int = 1
    max_guests: int = 2
    # Always the true per-night amount - see the model's comment. The host app
    # converts whatever unit it showed the host (nightly/weekly/monthly) to
    # this figure before it ever reaches the API.
    nightly_rate: float
    weekly_discount_percent: float = 0
    monthly_discount_percent: float = 0
    cleaning_fee: float = 0
    minimum_nights: int = Field(default=1, ge=1)
    breakfast_included: bool = False
    amenities: list[str] = []
    house_rules: str | None = None
    has_generator: bool = False
    has_inverter: bool = False
    has_24hr_electricity: bool = False
    is_gated_estate: bool = False
    has_security_guard: bool = False
    has_cctv: bool = False
    instant_book: bool = False


class ListingCreate(ListingBase):
    property_type: StayTypeSlug


class ListingUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    nightly_rate: float | None = None
    weekly_discount_percent: float | None = None
    monthly_discount_percent: float | None = None
    cleaning_fee: float | None = None
    minimum_nights: int | None = Field(default=None, ge=1)
    breakfast_included: bool | None = None
    amenities: list[str] | None = None
    house_rules: str | None = None
    has_generator: bool | None = None
    has_inverter: bool | None = None
    has_24hr_electricity: bool | None = None
    is_gated_estate: bool | None = None
    has_security_guard: bool | None = None
    has_cctv: bool | None = None
    instant_book: bool | None = None
    is_published: bool | None = None


class ListingOut(ListingBase):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    host_id: uuid.UUID
    is_published: bool
    photos: list[ListingPhotoOut] = []
    # Computed, not stored - see get_listing() in api/v1/listings.py. Defaults
    # here are only for other code paths that build a ListingOut without
    # going through that endpoint (e.g. host's own listing list); they are
    # not meaningful values, just a safe fallback.
    host_name: str = ""
    host_avatar_url: str | None = None
    host_review_count: int = 0
    host_rating: float | None = None
    host_years_hosting: int = 0
    is_guest_favourite: bool = False


class AvailabilityBlockCreate(BaseModel):
    start_date: date
    end_date: date
    is_blocked: bool = True
    override_nightly_rate: float | None = None


class AvailabilityBlockOut(AvailabilityBlockCreate):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    listing_id: uuid.UUID


class NearbyAreaOut(BaseModel):
    """A place near the guest that has stays available."""

    name: str
    city: str
    listing_count: int
    distance_km: float


class InteractionIn(BaseModel):
    """A browsing signal reported by the app.

    `anonymous_id` is a stable per-install identifier sent while signed out, so
    that browsing without an account still contributes to what is trending.
    It is ignored when the request is authenticated.
    """

    kind: str
    anonymous_id: str | None = None


class ListingAnalyticsOut(BaseModel):
    """One listing's performance, for the host's per-listing breakdown."""

    listing_id: uuid.UUID
    title: str
    views: int
    map_taps: int
    directions: int
    bookings: int
    revenue: float


class MonthlyTrendPoint(BaseModel):
    """One month's bookings and revenue, across all of a host's listings."""

    month: str  # "2026-09"
    bookings: int
    revenue: float


class HostAnalyticsOut(BaseModel):
    """Everything the host analytics screen needs in one call.

    Views/taps/directions come from `listing_interactions` (see
    api/v1/listings.py's own interaction-recording endpoint) - the same
    browsing signals that feed the guest recommendation model turn out to be
    exactly what a host wants to know too: how many people looked, and how
    many of them actually booked.
    """

    total_views: int
    total_map_taps: int
    total_directions: int
    total_bookings: int
    total_revenue: float
    # Bookings per view, as a guide to how well a listing's photos/price/copy
    # convert interest into a booking - not shown if there is no view data
    # yet, since a rate over zero views is meaningless rather than zero.
    conversion_rate: float | None
    listings: list[ListingAnalyticsOut]
    #: Oldest first, always 6 entries even for months with nothing in them -
    #: a flat trend line is real information, a missing month is not.
    monthly_trend: list[MonthlyTrendPoint]
