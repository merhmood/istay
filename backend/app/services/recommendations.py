"""Listing recommendations.

Content-based filtering is the engine here, for a concrete reason: collaborative
filtering learns from overlapping behaviour across many users ("people who booked
X also booked Y"), and with a young marketplace every co-occurrence count is zero,
so it returns nothing. Content-based filtering only needs *one* user's history plus
the attributes of the items, which is exactly what we have.

An item-item collaborative signal is implemented too, but it stays switched off
until the platform has enough interactions to make it meaningful (see
`MIN_INTERACTIONS_FOR_CF`). Once it activates it blends with, rather than replaces,
the content score - a hybrid, so a cold item is never stranded just because nobody
has booked it yet.

Both halves are fed from the full range of browsing behaviour, not just bookings
and favourites: detail views, map marker taps and directions requests all count,
weighted by how much intent each represents. This matters most for the
collaborative half, which needs overlapping behaviour between users to work at
all - bookings alone are far too sparse to ever produce an overlap, while views
accumulate fast enough to cross `MIN_INTERACTIONS_FOR_CF` in realistic use.

Nothing here is a trained model; it is explicit, inspectable scoring.
"""
from __future__ import annotations

import math
from collections import defaultdict
from dataclasses import dataclass

from app.models.listing import Listing

# Weights for the content score. They sum to 1 so the result stays in 0..1 and
# stays readable when debugging why something was recommended.
W_CITY = 0.30
W_PRICE = 0.20
W_AMENITIES = 0.20
W_ESSENTIALS = 0.15
W_PROPERTY_TYPE = 0.10
W_CAPACITY = 0.05

# How much each action counts when building the taste profile, ordered by how
# much commitment it represents.
#
# Bookings lead because money changed hands. Asking for directions sits just
# below them and above favourites: nobody opens Bolt for a place they are idly
# browsing, whereas a heart costs one tap and is often aspirational. Views are
# deliberately small - they are the noisiest signal, but there are two orders of
# magnitude more of them, so in aggregate they carry the profile for the many
# guests who have never booked anything yet.
WEIGHT_BOOKING = 3.0
WEIGHT_DIRECTIONS = 2.0
WEIGHT_FAVORITE = 1.0
WEIGHT_VIEW = 0.4
WEIGHT_MAP_VIEW = 0.25

# Repeat engagement is real signal - going back to the same listing four times
# means something - but it must not let one obsessively-revisited listing define
# the whole profile. Growth is sub-linear and capped.
REPEAT_CAP = 3.0


def repeat_weight(base_weight: float, occurrences: int) -> float:
    """Total weight for `occurrences` of the same action on the same listing.

    Square-root growth: the 2nd view adds ~41% of the first, the 10th adds ~5%.
    """
    if occurrences <= 0:
        return 0.0
    return base_weight * min(math.sqrt(occurrences), REPEAT_CAP)

# Below this, item-item co-occurrence is noise rather than signal.
MIN_INTERACTIONS_FOR_CF = 60
# Share of the final score the collaborative signal may claim once it is active.
CF_BLEND = 0.35

# Beyond this, a listing is dropped from the feed outright rather than merely
# ranked lower - a great taste match on the other side of the country is still
# a bad suggestion for a feed meant to answer "what's near me that I'd like".
MAX_RECOMMENDATION_DISTANCE_KM = 150.0


# Expanding rings for ranking, not filtering - MAX_RECOMMENDATION_DISTANCE_KM
# above still decides what's in the pool at all. A guest a few minutes from
# three mediocre matches should see those before a perfect-taste match two
# hours away: feed order is primarily "closest ring first", with taste only
# breaking ties *inside* a ring, rather than one weighted score where a great
# taste match could out-rank a much nearer, merely-good one.
PROXIMITY_BANDS_KM = (5.0, 15.0, 40.0, 100.0)


def proximity_band(distance_km: float | None) -> int:
    """Which ring `distance_km` falls into - 0 is closest. `None` (no guest
    location known) sorts into the outermost ring, so distance never reorders
    a feed that has nothing to compare it against."""
    if distance_km is None:
        return len(PROXIMITY_BANDS_KM)
    for index, threshold in enumerate(PROXIMITY_BANDS_KM):
        if distance_km <= threshold:
            return index
    return len(PROXIMITY_BANDS_KM)


@dataclass
class Interaction:
    """One user touching one listing, with how much it should count."""

    user_id: str
    listing_id: str
    weight: float


def _essentials(listing: Listing) -> set[str]:
    """The Nigeria-specific attributes guests filter on hardest."""
    flags = {
        "generator": listing.has_generator,
        "inverter": listing.has_inverter,
        "electricity_24h": listing.has_24hr_electricity,
        "gated": listing.is_gated_estate,
        "guard": listing.has_security_guard,
        "cctv": listing.has_cctv,
    }
    return {name for name, present in flags.items() if present}


def _jaccard(a: set[str], b: set[str]) -> float:
    if not a and not b:
        return 0.0
    union = a | b
    if not union:
        return 0.0
    return len(a & b) / len(union)


def _price_affinity(rate: float, preferred: float) -> float:
    """1.0 at the guest's usual price, decaying as it diverges.

    Compared on a log scale because price perception is proportional: ₦40k vs
    ₦80k is the same felt jump as ₦80k vs ₦160k, which a linear difference would
    get badly wrong across a range this wide.
    """
    if rate <= 0 or preferred <= 0:
        return 0.0
    ratio = math.log(rate / preferred)
    return math.exp(-(ratio**2) / 0.5)


def _capacity_affinity(listing: Listing, preferred_guests: float) -> float:
    """Rewards fitting the party; heavily penalises being too small."""
    if preferred_guests <= 0:
        return 0.0
    if listing.max_guests < preferred_guests:
        return 0.0
    # Fits, but a 10-guest villa for a solo traveller is a poor suggestion.
    excess = listing.max_guests - preferred_guests
    return 1.0 / (1.0 + 0.35 * excess)


@dataclass
class TasteProfile:
    """What we believe the guest likes, derived from what they have done."""

    cities: dict[str, float]
    property_types: dict[str, float]
    amenities: dict[str, float]
    essentials: dict[str, float]
    avg_price: float
    avg_guests: float
    total_weight: float

    @property
    def is_empty(self) -> bool:
        return self.total_weight <= 0


def build_taste_profile(weighted_listings: list[tuple[Listing, float]]) -> TasteProfile:
    cities: dict[str, float] = defaultdict(float)
    property_types: dict[str, float] = defaultdict(float)
    amenities: dict[str, float] = defaultdict(float)
    essentials: dict[str, float] = defaultdict(float)
    price_total = 0.0
    guests_total = 0.0
    total_weight = 0.0

    for listing, weight in weighted_listings:
        cities[listing.city] += weight
        property_types[listing.property_type] += weight
        for amenity in listing.amenities or []:
            amenities[amenity] += weight
        for essential in _essentials(listing):
            essentials[essential] += weight
        price_total += float(listing.nightly_rate) * weight
        guests_total += listing.max_guests * weight
        total_weight += weight

    return TasteProfile(
        cities=dict(cities),
        property_types=dict(property_types),
        amenities=dict(amenities),
        essentials=dict(essentials),
        avg_price=price_total / total_weight if total_weight else 0.0,
        avg_guests=guests_total / total_weight if total_weight else 0.0,
        total_weight=total_weight,
    )


def content_score(listing: Listing, profile: TasteProfile) -> tuple[float, str | None]:
    """Score a candidate against the profile, with the strongest reason why."""
    if profile.is_empty:
        return 0.0, None

    city_affinity = profile.cities.get(listing.city, 0.0) / profile.total_weight
    type_affinity = profile.property_types.get(listing.property_type, 0.0) / profile.total_weight
    price_affinity = _price_affinity(float(listing.nightly_rate), profile.avg_price)
    capacity_affinity = _capacity_affinity(listing, profile.avg_guests)

    # Compare sets against the profile's *preferred* attributes - those seen in
    # at least a quarter of the weighted history, so a single outlier booking
    # doesn't define taste.
    threshold = profile.total_weight * 0.25
    preferred_amenities = {name for name, weight in profile.amenities.items() if weight >= threshold}
    preferred_essentials = {name for name, weight in profile.essentials.items() if weight >= threshold}
    amenity_affinity = _jaccard(set(listing.amenities or []), preferred_amenities)
    essentials_affinity = _jaccard(_essentials(listing), preferred_essentials)

    score = (
        W_CITY * city_affinity
        + W_PRICE * price_affinity
        + W_AMENITIES * amenity_affinity
        + W_ESSENTIALS * essentials_affinity
        + W_PROPERTY_TYPE * type_affinity
        + W_CAPACITY * capacity_affinity
    )

    contributions = {
        f"More stays in {listing.city}": W_CITY * city_affinity,
        "Around your usual price": W_PRICE * price_affinity,
        "Has the amenities you look for": W_AMENITIES * amenity_affinity,
        "Power and security you rely on": W_ESSENTIALS * essentials_affinity,
        f"Another {listing.property_type} like you've booked": W_PROPERTY_TYPE * type_affinity,
    }
    top_reason, top_value = max(contributions.items(), key=lambda item: item[1])
    return score, top_reason if top_value > 0.05 else None


def popularity_score(listing: Listing, review_stats: dict[str, tuple[int, float]]) -> float:
    """Cold-start ranking: no history, so lean on quality and completeness."""
    count, average = review_stats.get(str(listing.id), (0, 0.0))
    # Bayesian-ish damping: 5 reviews at 5.0 should outrank 1 review at 5.0.
    rating_component = (average / 5.0) * (count / (count + 3)) if count else 0.0
    amenity_component = min(len(listing.amenities or []) / 8.0, 1.0)
    essentials_component = len(_essentials(listing)) / 6.0
    return 0.45 * rating_component + 0.30 * essentials_component + 0.25 * amenity_component


def item_item_scores(
    interactions: list[Interaction],
    seed_listing_ids: set[str],
) -> dict[str, float]:
    """Item-item collaborative filtering over binary user-item interactions.

    Cosine similarity between listings, where a listing is the set of users who
    engaged with it. Returns a co-occurrence score per candidate against the
    guest's own listings. Yields an empty result on sparse data, which is the
    correct answer rather than a misleading one.
    """
    if len(interactions) < MIN_INTERACTIONS_FOR_CF or not seed_listing_ids:
        return {}

    users_by_listing: dict[str, set[str]] = defaultdict(set)
    for interaction in interactions:
        users_by_listing[interaction.listing_id].add(interaction.user_id)

    scores: dict[str, float] = {}
    for candidate_id, candidate_users in users_by_listing.items():
        if candidate_id in seed_listing_ids or not candidate_users:
            continue
        total = 0.0
        for seed_id in seed_listing_ids:
            seed_users = users_by_listing.get(seed_id)
            if not seed_users:
                continue
            overlap = len(candidate_users & seed_users)
            if overlap:
                total += overlap / math.sqrt(len(candidate_users) * len(seed_users))
        if total:
            scores[candidate_id] = total

    # Normalise to 0..1 so the blend weight means what it says.
    peak = max(scores.values(), default=0.0)
    if peak <= 0:
        return {}
    return {listing_id: value / peak for listing_id, value in scores.items()}
