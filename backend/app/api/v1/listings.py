import re
import uuid
from collections import defaultdict
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import String, case, cast, func, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.nigeria_states import NIGERIA_STATES
from app.core.security import get_current_host, get_current_user, get_optional_user
from app.core.stay_types import LEGACY_ALIASES, STAY_TYPES, normalize_stay_type
from app.db.session import get_db
from app.models.booking import Booking, BookingStatus
from app.models.favorite import Favorite
from app.models.listing import Listing, ListingPhoto
from app.models.listing_interaction import InteractionKind, ListingInteraction
from app.models.review import Review
from app.models.user import User
from app.services.fuzzy import fuzzy_matches
from app.services.geo import haversine_km
from app.services.storage import save_upload
from app.services.recommendations import (
    CF_BLEND,
    MAX_RECOMMENDATION_DISTANCE_KM,
    WEIGHT_BOOKING,
    WEIGHT_DIRECTIONS,
    WEIGHT_FAVORITE,
    WEIGHT_MAP_VIEW,
    WEIGHT_VIEW,
    Interaction,
    build_taste_profile,
    content_score,
    item_item_scores,
    popularity_score,
    proximity_band,
    repeat_weight,
)
from app.schemas.listing import (
    HostAnalyticsOut,
    InteractionIn,
    ListingAnalyticsOut,
    ListingCreate,
    ListingOut,
    ListingPhotoOut,
    ListingUpdate,
    MonthlyTrendPoint,
    NearbyAreaOut,
)

router = APIRouter(prefix="/listings", tags=["listings"])


@router.get("", response_model=list[ListingOut])
async def search_listings(
    city: str | None = None,
    min_price: float | None = None,
    max_price: float | None = None,
    max_guests: int | None = None,
    has_generator: bool | None = None,
    has_inverter: bool | None = None,
    has_24hr_electricity: bool | None = None,
    is_gated_estate: bool | None = None,
    has_security_guard: bool | None = None,
    has_cctv: bool | None = None,
    property_type: str | None = None,
    amenities: list[str] = Query(default=[]),
    db: AsyncSession = Depends(get_db),
) -> list[Listing]:
    query = select(Listing).options(selectinload(Listing.photos)).where(Listing.is_published.is_(True))

    relevance = None
    if city:
        relevance = _relevance_expression(city)
        # Keep anything the ranker considers a plausible match. Substring still
        # counts, because "Lekki" appearing mid-title is an obvious hit that
        # neither stemming nor trigrams should be trusted to outrank.
        pattern = f"%{city}%"
        conditions = (
            Listing.city.ilike(pattern)
            | Listing.neighborhood_landmark.ilike(pattern)
            | Listing.title.ilike(pattern)
            | (relevance > 0.08)
        )
        # The explore screen has one search box for "city, area, stay type, or
        # state" - it doesn't ask the guest which kind of thing they're typing,
        # so a search for "studio", "hotel", or "Rivers State" needs to hit
        # here too, not just a place name. Both are fuzzy (see fuzzy.py), so a
        # typo like "hotell" or "riverss" still resolves.
        stay_type_matches = _matching_stay_type_slugs(city)
        if stay_type_matches:
            conditions = conditions | Listing.property_type.in_(stay_type_matches)
        state_city_matches = _matching_state_cities(city)
        for state_city in state_city_matches:
            conditions = conditions | Listing.city.ilike(f"%{state_city}%")
        query = query.where(conditions)
    if min_price is not None:
        query = query.where(Listing.nightly_rate >= min_price)
    if max_price is not None:
        query = query.where(Listing.nightly_rate <= max_price)
    if max_guests is not None:
        query = query.where(Listing.max_guests >= max_guests)
    if has_generator is not None:
        query = query.where(Listing.has_generator == has_generator)
    if has_inverter is not None:
        query = query.where(Listing.has_inverter == has_inverter)
    if has_24hr_electricity is not None:
        query = query.where(Listing.has_24hr_electricity == has_24hr_electricity)
    if is_gated_estate is not None:
        query = query.where(Listing.is_gated_estate == is_gated_estate)
    if has_security_guard is not None:
        query = query.where(Listing.has_security_guard == has_security_guard)
    if has_cctv is not None:
        query = query.where(Listing.has_cctv == has_cctv)
    if property_type is not None:
        # Normalised so a client passing the old free-text values ("apartment")
        # still matches listings already stored under the canonical slug.
        query = query.where(Listing.property_type == normalize_stay_type(property_type))
    for amenity in amenities:
        query = query.where(Listing.amenities.any(amenity))

    # Relevance first when there's a query; recency is only a sensible default
    # for an unfiltered browse.
    order = (relevance.desc(), Listing.created_at.desc()) if relevance is not None else (Listing.created_at.desc(),)
    result = await db.execute(query.order_by(*order))
    return list(result.scalars().all())


def _matching_stay_type_slugs(term: str) -> list[str]:
    """Slugs whose label, slug, or legacy alias fuzzily matches the search term.

    Fuzzy (see fuzzy.py) so a typo like "studioo" or "hotell" still resolves,
    not just an exact substring. Kept to a minimum length so short/common
    fragments ("in", "ho") don't silently pull in every stay type and swallow
    what was meant as a place search.
    """
    needle = term.strip()
    if len(needle) < 3:
        return []

    matches: set[str] = set()
    for alias, slug in LEGACY_ALIASES.items():
        if fuzzy_matches(needle, [alias]):
            matches.add(slug)
    for stay_type in STAY_TYPES:
        if fuzzy_matches(needle, [stay_type.label, stay_type.slug.replace("_", " ")]):
            matches.add(stay_type.slug)
    return list(matches)


def _matching_state_cities(term: str) -> list[str]:
    """Cities of any Nigerian state whose name or alias fuzzily matches the
    search term - see nigeria_states.py for why a state resolves to a city
    rather than filtering a (non-existent) state column directly.
    """
    needle = term.strip()
    if len(needle) < 3:
        return []

    cities: set[str] = set()
    for state in NIGERIA_STATES:
        if fuzzy_matches(needle, [state.name, *state.aliases]):
            cities.add(state.city)
    return list(cities)


def _relevance_expression(term: str):
    """Rank listings against a free-text query.

    Combines three signals because each covers the others' blind spots:

    * full-text rank, weighted so title/city beat description, and stemmed so
      "apartments" matches "apartment";
    * trigram similarity, which survives the misspellings full-text cannot -
      "leki" -> "Lekki", "gwarimpa" -> "Gwarinpa";
    * a prefix bonus, so typing "lek" ranks Lekki above an unrelated listing
      that merely mentions it in passing.
    """
    query_text = term.strip()
    vector = func.to_tsvector("english", _searchable_text())
    full_text = func.ts_rank(vector, func.plainto_tsquery("english", query_text))

    # Greatest across fields: a strong hit anywhere is what matters, and
    # averaging would dilute it.
    fuzzy = func.greatest(
        func.similarity(Listing.city, query_text),
        func.similarity(Listing.neighborhood_landmark, query_text),
        func.similarity(Listing.title, query_text),
    )
    prefix_bonus = func.greatest(
        case((Listing.city.ilike(f"{query_text}%"), 1.0), else_=0.0),
        case((Listing.neighborhood_landmark.ilike(f"%{query_text}%"), 0.6), else_=0.0),
        case((Listing.title.ilike(f"%{query_text}%"), 0.5), else_=0.0),
    )

    return (full_text * 2.0) + (fuzzy * 1.5) + (prefix_bonus * 1.0)


def _searchable_text():
    """The concatenated text the full-text vector is built from."""
    return (
        func.coalesce(Listing.title, "")
        + " "
        + func.coalesce(Listing.city, "")
        + " "
        + func.coalesce(Listing.neighborhood_landmark, "")
        + " "
        + func.coalesce(Listing.property_type, "")
        + " "
        + func.coalesce(Listing.description, "")
    )


@router.get("/areas-nearby", response_model=list[NearbyAreaOut])
async def areas_nearby(
    latitude: float,
    longitude: float,
    radius_km: float = Query(default=60, ge=1, le=1000),
    limit: int = Query(default=8, ge=1, le=30),
    db: AsyncSession = Depends(get_db),
) -> list[NearbyAreaOut]:
    """Places near the guest that actually have stays, nearest first.

    The app previously sourced these chips from OpenStreetMap place names around
    the device. Those are real places but most have no listings, so tapping one
    returned an empty search. Deriving the list from published listings instead
    guarantees every suggestion leads somewhere, and carries a count so the app
    can show how much is there.
    """
    result = await db.execute(
        select(
            Listing.city,
            Listing.neighborhood_landmark,
            Listing.title,
            Listing.latitude,
            Listing.longitude,
        ).where(Listing.is_published.is_(True))
    )

    # Distances are computed here rather than in SQL: the listing count is small,
    # and this keeps the haversine readable and database-agnostic.
    nearest: dict[str, float] = {}
    counts: dict[str, int] = {}
    cities: dict[str, str] = {}
    for city, landmark, title, lat, lng in result.all():
        distance = haversine_km(latitude, longitude, float(lat), float(lng))
        if distance > radius_km:
            continue
        # Group by neighbourhood, not city. "Abuja" is useless to a guest who is
        # already in Abuja; "Jabi" and "Wuse 2" are what they actually choose
        # between. Falls back to the city when no area can be identified.
        area = _area_name(title, landmark) or city
        counts[area] = counts.get(area, 0) + 1
        cities[area] = city
        # An area's distance is that of its closest listing, so it is ranked by
        # how near the guest can actually stay.
        if area not in nearest or distance < nearest[area]:
            nearest[area] = distance

    areas = [
        NearbyAreaOut(
            name=area,
            city=cities[area],
            listing_count=counts[area],
            distance_km=round(distance, 1),
        )
        for area, distance in nearest.items()
    ]
    areas.sort(key=lambda area: area.distance_km)
    return areas[:limit]


# Titles are written "<something> in <Area>" or "<something> near <Area>", which
# is the only structured-enough area signal the data currently carries. A proper
# `area` column filled in at listing creation would be the real fix.
_AREA_PATTERN = re.compile(r"\b(?:in|near|at)\s+(.+)$", re.IGNORECASE)
# Trailing qualifiers that are not part of the area name: "Lekki Phase 1"
# is the area "Lekki", and anything after a comma is a wider region.
_AREA_NOISE = re.compile(r"\s*(?:,.*|\b(?:phase|district)\b.*)$", re.IGNORECASE)


def _area_name(title: str, landmark: str) -> str | None:
    match = _AREA_PATTERN.search(title or "")
    if not match:
        return None
    area = _AREA_NOISE.sub("", match.group(1)).strip()
    # Guard against a title whose tail is a whole phrase rather than a place.
    if not area or len(area) > 30 or len(area.split()) > 3:
        return None
    return area


_INTERACTION_WEIGHTS = {
    InteractionKind.DIRECTIONS: WEIGHT_DIRECTIONS,
    InteractionKind.VIEW: WEIGHT_VIEW,
    InteractionKind.MAP_VIEW: WEIGHT_MAP_VIEW,
}


@router.post("/{listing_id}/interactions", status_code=status.HTTP_204_NO_CONTENT)
async def record_interaction(
    listing_id: uuid.UUID,
    payload: InteractionIn,
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Record a browsing signal: a detail view, a map tap or a directions request.

    Deliberately forgiving. This is telemetry feeding a ranking model, not a
    transaction - an unknown listing id or an unrecognised kind is dropped
    quietly rather than surfaced to the guest, because no user-visible action
    should ever fail because analytics did.
    """
    if payload.kind not in InteractionKind.ALL:
        return None

    exists = await db.execute(select(Listing.id).where(Listing.id == listing_id))
    if exists.scalar_one_or_none() is None:
        return None

    # A signed-in user is identified by their account; storing the device id
    # alongside it would be tracking we have no use for.
    anonymous_id = None
    if current_user is None and payload.anonymous_id:
        anonymous_id = payload.anonymous_id[:64]

    db.add(
        ListingInteraction(
            user_id=current_user.id if current_user else None,
            anonymous_id=anonymous_id,
            listing_id=listing_id,
            kind=payload.kind,
        )
    )
    await db.commit()
    return None


@router.get("/recommended", response_model=list[ListingOut])
async def recommended_listings(
    limit: int = Query(default=10, ge=1, le=30),
    latitude: float | None = None,
    longitude: float | None = None,
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> list[Listing]:
    """Hybrid content-based feed - see app/services/recommendations.py for why
    content-based leads and collaborative filtering only blends in once there is
    enough interaction data for it to mean anything.

    Anonymous browsers get the cold-start popularity feed: browsing the home
    screen shouldn't require an account.

    When the client sends a location, it is used twice: first to drop anything
    past `MAX_RECOMMENDATION_DISTANCE_KM` outright (falling back to the
    unfiltered pool only if that would leave nothing at all - a distant
    suggestion beats an empty feed), then again as a scoring term so the
    nearest of what remains still wins ties against taste/popularity alone.
    """
    # 1. What has this guest actually engaged with? Bookings count for more than
    #    favourites, because paying to stay somewhere is the stronger signal.
    history: list[tuple[Listing, float]] = []
    # Two different jobs, deliberately kept apart: `seed_listing_ids` are the
    # listings whose neighbours collaborative filtering should look for, while
    # `exclude_listing_ids` are the ones it makes no sense to recommend again.
    # A listing the guest asked directions to belongs in the first set but not
    # the second - it is a strong taste signal, yet they never stayed there, so
    # suggesting it is still useful.
    seed_listing_ids: set[str] = set()
    exclude_listing_ids: set[str] = set()
    if current_user is not None:
        booked = await db.execute(
            select(Listing)
            .join(Booking, Booking.listing_id == Listing.id)
            .where(Booking.guest_id == current_user.id)
        )
        for listing in booked.scalars().unique().all():
            history.append((listing, WEIGHT_BOOKING))
            seed_listing_ids.add(str(listing.id))
            exclude_listing_ids.add(str(listing.id))

        favorited = await db.execute(
            select(Listing)
            .join(Favorite, Favorite.listing_id == Listing.id)
            .where(Favorite.user_id == current_user.id)
        )
        for listing in favorited.scalars().unique().all():
            history.append((listing, WEIGHT_FAVORITE))
            seed_listing_ids.add(str(listing.id))
            exclude_listing_ids.add(str(listing.id))

        # Browsing signals: what they opened, what they tapped on the map and -
        # the strongest of the three - what they asked directions to. For a guest
        # who has not booked yet this is the entire profile, and for one who has,
        # it is what keeps the feed current between trips.
        browsed = await db.execute(
            select(Listing, ListingInteraction.kind, func.count(ListingInteraction.id))
            .join(ListingInteraction, ListingInteraction.listing_id == Listing.id)
            .where(ListingInteraction.user_id == current_user.id)
            .group_by(Listing.id, ListingInteraction.kind)
        )
        for listing, kind, occurrences in browsed.all():
            base = _INTERACTION_WEIGHTS.get(kind)
            if base is None:
                continue
            history.append((listing, repeat_weight(base, int(occurrences))))
            # Directions are intentful enough to seed the collaborative half:
            # "people who looked up how to get to this place also liked..." is
            # exactly the kind of neighbour relation it is built to find. Passive
            # views are not - almost everyone views almost everything.
            if kind == InteractionKind.DIRECTIONS:
                seed_listing_ids.add(str(listing.id))

    # 2. Candidate pool: published, not the viewer's own, not already booked.
    candidates_query = (
        select(Listing).options(selectinload(Listing.photos)).where(Listing.is_published.is_(True))
    )
    if current_user is not None:
        candidates_query = candidates_query.where(Listing.host_id != current_user.id)
        if exclude_listing_ids:
            candidates_query = candidates_query.where(Listing.id.notin_(exclude_listing_ids))
    candidates_result = await db.execute(candidates_query.order_by(Listing.created_at.desc()).limit(300))
    candidates = list(candidates_result.scalars().all())
    if not candidates:
        return []

    # 2b. Location: drop anything too far to realistically be "near me", unless
    #     that would leave the feed empty. Distances are kept regardless, so
    #     step 4/5 below can still favour the nearest of whatever remains.
    distance_by_id: dict[str, float] = {}
    if latitude is not None and longitude is not None:
        distance_by_id = {
            str(listing.id): haversine_km(latitude, longitude, float(listing.latitude), float(listing.longitude))
            for listing in candidates
        }
        nearby = [c for c in candidates if distance_by_id[str(c.id)] <= MAX_RECOMMENDATION_DISTANCE_KM]
        if nearby:
            candidates = nearby

    # 3. Review stats power the quality prior used for cold start and as a
    #    tie-breaker, so a well-reviewed place isn't buried by a brand new one.
    review_rows = await db.execute(
        select(
            Review.listing_id,
            func.count(Review.id),
            func.avg(
                (Review.cleanliness + Review.communication + Review.accuracy + Review.location_rating + Review.value)
                / 5.0
            ),
        ).group_by(Review.listing_id)
    )
    review_stats = {str(row[0]): (int(row[1]), float(row[2] or 0)) for row in review_rows.all()}

    # 4. Cold start - no history, or signed out entirely. Closest ring first,
    #    quality within it - see proximity_band's docstring for why this is a
    #    sort key rather than another term blended into one score.
    if not history:
        def cold_start_key(listing: Listing) -> tuple[int, float]:
            band = proximity_band(distance_by_id.get(str(listing.id))) if distance_by_id else 0
            score = popularity_score(listing, review_stats)
            return (band, -score)

        ranked = sorted(candidates, key=cold_start_key)
        return ranked[:limit]

    profile = build_taste_profile(history)

    # 5. Collaborative signal, active only once the platform has the density for
    #    it. Bookings and favourites alone never reached that density - the whole
    #    point of collecting browsing signals is that views and directions do,
    #    because every guest generates dozens of them. Anonymous rows are keyed
    #    by device id, which is a perfectly good user identity for co-occurrence.
    #    Every branch is cast to text: the anonymous device id is a string while
    #    the other identifiers are UUIDs, and Postgres rejects a UNION whose
    #    branches disagree on column type.
    interaction_rows = await db.execute(
        union_all(
            select(
                cast(Booking.guest_id, String).label("actor"),
                cast(Booking.listing_id, String).label("listing"),
            ),
            select(cast(Favorite.user_id, String), cast(Favorite.listing_id, String)),
            select(
                func.coalesce(
                    cast(ListingInteraction.user_id, String),
                    ListingInteraction.anonymous_id,
                ),
                cast(ListingInteraction.listing_id, String),
            ).where(
                ListingInteraction.user_id.isnot(None)
                | ListingInteraction.anonymous_id.isnot(None)
            ),
        )
    )
    interactions = [Interaction(user_id=str(row[0]), listing_id=str(row[1]), weight=1.0) for row in interaction_rows.all()]
    cf_scores = item_item_scores(interactions, seed_listing_ids)
    cf_weight = CF_BLEND if cf_scores else 0.0

    # Closest ring first, taste/quality as the tie-breaker within it - same
    # reasoning as the cold-start branch above.
    scored: list[tuple[int, float, Listing]] = []
    for listing in candidates:
        content, _reason = content_score(listing, profile)
        collaborative = cf_scores.get(str(listing.id), 0.0)
        blended = (1 - cf_weight) * content + cf_weight * collaborative
        # Small quality nudge so near-ties resolve toward better-reviewed places.
        blended += 0.08 * popularity_score(listing, review_stats)
        band = proximity_band(distance_by_id.get(str(listing.id))) if distance_by_id else 0
        scored.append((band, blended, listing))

    scored.sort(key=lambda triple: (triple[0], -triple[1]))
    return [listing for _band, _score, listing in scored[:limit]]


@router.get("/mine", response_model=list[ListingOut])
async def my_listings(
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> list[Listing]:
    query = (
        select(Listing)
        .options(selectinload(Listing.photos))
        .where(Listing.host_id == current_user.id)
        .order_by(Listing.created_at.desc())
    )
    result = await db.execute(query)
    return list(result.scalars().all())


@router.get("/analytics", response_model=HostAnalyticsOut)
async def host_analytics(
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> HostAnalyticsOut:
    """Views, taps, directions and bookings across every listing this host
    owns. Declared before `/{listing_id}` - FastAPI matches routes in
    declaration order, and a bare `/{listing_id}` route ahead of this one
    would swallow `analytics` as if it were a (invalid) listing id.
    """
    listing_rows = await db.execute(
        select(Listing.id, Listing.title).where(Listing.host_id == current_user.id)
    )
    listings = listing_rows.all()
    listing_ids = [row.id for row in listings]
    if not listing_ids:
        return HostAnalyticsOut(
            total_views=0,
            total_map_taps=0,
            total_directions=0,
            total_bookings=0,
            total_revenue=0,
            conversion_rate=None,
            listings=[],
            monthly_trend=_empty_monthly_trend(),
        )

    interaction_rows = await db.execute(
        select(ListingInteraction.listing_id, ListingInteraction.kind, func.count(ListingInteraction.id))
        .where(ListingInteraction.listing_id.in_(listing_ids))
        .group_by(ListingInteraction.listing_id, ListingInteraction.kind)
    )
    interaction_counts: dict[uuid.UUID, dict[str, int]] = defaultdict(dict)
    for listing_id, kind, count in interaction_rows.all():
        interaction_counts[listing_id][kind] = int(count)

    # Only bookings a host actually gets paid for count as "performance" -
    # a pending request that was never approved isn't a conversion.
    earned_statuses = (BookingStatus.CONFIRMED, BookingStatus.COMPLETED)
    booking_rows = await db.execute(
        select(Booking.listing_id, func.count(Booking.id), func.coalesce(func.sum(Booking.host_payout_amount), 0))
        .where(Booking.listing_id.in_(listing_ids), Booking.status.in_(earned_statuses))
        .group_by(Booking.listing_id)
    )
    booking_counts: dict[uuid.UUID, tuple[int, float]] = {
        row[0]: (int(row[1]), float(row[2])) for row in booking_rows.all()
    }

    per_listing: list[ListingAnalyticsOut] = []
    total_views = total_map_taps = total_directions = total_bookings = 0
    total_revenue = 0.0
    for listing_id, title in listings:
        kinds = interaction_counts.get(listing_id, {})
        views = kinds.get(InteractionKind.VIEW, 0)
        map_taps = kinds.get(InteractionKind.MAP_VIEW, 0)
        directions = kinds.get(InteractionKind.DIRECTIONS, 0)
        bookings, revenue = booking_counts.get(listing_id, (0, 0.0))

        per_listing.append(
            ListingAnalyticsOut(
                listing_id=listing_id,
                title=title,
                views=views,
                map_taps=map_taps,
                directions=directions,
                bookings=bookings,
                revenue=revenue,
            )
        )
        total_views += views
        total_map_taps += map_taps
        total_directions += directions
        total_bookings += bookings
        total_revenue += revenue

    # Busiest listings first - the ranking a host actually wants ("what's
    # working") rather than creation order.
    per_listing.sort(key=lambda l: l.views, reverse=True)

    monthly_trend = await _monthly_booking_trend(db, listing_ids, earned_statuses)

    return HostAnalyticsOut(
        total_views=total_views,
        total_map_taps=total_map_taps,
        total_directions=total_directions,
        total_bookings=total_bookings,
        total_revenue=total_revenue,
        conversion_rate=(total_bookings / total_views) if total_views > 0 else None,
        listings=per_listing,
        monthly_trend=monthly_trend,
    )


def _month_key(dt: date) -> str:
    return f"{dt.year:04d}-{dt.month:02d}"


def _last_six_months() -> list[date]:
    """The first day of each of the last 6 calendar months, oldest first."""
    today = date.today()
    months = []
    year, month = today.year, today.month
    for _ in range(6):
        months.append(date(year, month, 1))
        month -= 1
        if month == 0:
            month = 12
            year -= 1
    return list(reversed(months))


def _empty_monthly_trend() -> list[MonthlyTrendPoint]:
    return [MonthlyTrendPoint(month=_month_key(m), bookings=0, revenue=0) for m in _last_six_months()]


async def _monthly_booking_trend(
    db: AsyncSession, listing_ids: list[uuid.UUID], earned_statuses: tuple[BookingStatus, ...]
) -> list[MonthlyTrendPoint]:
    months = _last_six_months()
    earliest = months[0]

    rows = await db.execute(
        select(Booking.check_in, Booking.host_payout_amount)
        .where(
            Booking.listing_id.in_(listing_ids),
            Booking.status.in_(earned_statuses),
            Booking.check_in >= earliest,
        )
    )
    buckets: dict[str, list[float]] = defaultdict(list)
    for check_in, payout in rows.all():
        buckets[_month_key(check_in)].append(float(payout))

    return [
        MonthlyTrendPoint(
            month=_month_key(m),
            bookings=len(buckets.get(_month_key(m), [])),
            revenue=sum(buckets.get(_month_key(m), [])),
        )
        for m in months
    ]


# Below this review count, a listing's average is too noisy to call out as a
# "favourite" (one 5-star review would otherwise instantly qualify) or to
# rank fairly against listings with a real review history.
_MIN_REVIEWS_FOR_BADGE = 3
# How exclusive the badge is - top 10% of listings that clear the review-count
# bar above.
_GUEST_FAVOURITE_PERCENTILE = 0.10

# Same per-review average used by the recommendation feed (app/services/
# recommendations.py's review_stats query) - duplicated rather than imported
# since that module scores the discovery *feed*, a different concern from a
# single listing's own detail stats, and re-exporting a bare SQL expression
# across that boundary isn't worth it for one line.
_AVG_RATING_EXPR = (Review.cleanliness + Review.communication + Review.accuracy + Review.location_rating + Review.value) / 5.0


@router.get("/{listing_id}", response_model=ListingOut)
async def get_listing(listing_id: uuid.UUID, db: AsyncSession = Depends(get_db)) -> ListingOut:
    query = (
        select(Listing)
        .options(selectinload(Listing.photos), selectinload(Listing.host))
        .where(Listing.id == listing_id)
    )
    result = await db.execute(query)
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")

    # Host stats: aggregated across every listing this host owns, not just
    # the one being viewed - that's what "460 Reviews Β· 4.97 Rating" means on
    # a host's profile.
    host_stats_row = (
        await db.execute(
            select(func.count(Review.id), func.avg(_AVG_RATING_EXPR))
            .select_from(Review)
            .join(Listing, Listing.id == Review.listing_id)
            .where(Listing.host_id == listing.host_id)
        )
    ).one()
    host_review_count = int(host_stats_row[0] or 0)
    host_rating = float(host_stats_row[1]) if host_stats_row[1] is not None else None
    host_years_hosting = max(0, (datetime.now(timezone.utc) - listing.host.created_at).days // 365)

    # Guest favourite: this listing's own average has to clear the review-
    # count bar, then rank in the top percentile among every other published
    # listing that also clears it.
    own_stats_row = (
        await db.execute(
            select(func.count(Review.id), func.avg(_AVG_RATING_EXPR)).where(Review.listing_id == listing.id)
        )
    ).one()
    own_review_count = int(own_stats_row[0] or 0)
    own_rating = float(own_stats_row[1]) if own_stats_row[1] is not None else None

    is_guest_favourite = False
    if own_review_count >= _MIN_REVIEWS_FOR_BADGE and own_rating is not None:
        eligible_ratings_rows = await db.execute(
            select(func.avg(_AVG_RATING_EXPR))
            .select_from(Review)
            .join(Listing, Listing.id == Review.listing_id)
            .where(Listing.is_published.is_(True))
            .group_by(Review.listing_id)
            .having(func.count(Review.id) >= _MIN_REVIEWS_FOR_BADGE)
        )
        eligible_ratings = sorted((float(row[0]) for row in eligible_ratings_rows.all()), reverse=True)
        if eligible_ratings:
            rank = sum(1 for rating in eligible_ratings if rating >= own_rating)
            is_guest_favourite = (rank / len(eligible_ratings)) <= _GUEST_FAVOURITE_PERCENTILE

    return ListingOut.model_validate(listing).model_copy(
        update={
            "host_name": listing.host.full_name,
            "host_avatar_url": listing.host.avatar_url,
            "host_review_count": host_review_count,
            "host_rating": host_rating,
            "host_years_hosting": host_years_hosting,
            "is_guest_favourite": is_guest_favourite,
        }
    )


@router.post("", response_model=ListingOut, status_code=status.HTTP_201_CREATED)
async def create_listing(
    payload: ListingCreate,
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> Listing:
    listing = Listing(host_id=current_user.id, **payload.model_dump())
    db.add(listing)
    await db.commit()
    await db.refresh(listing, attribute_names=["photos"])
    return listing


async def _get_owned_listing(listing_id: uuid.UUID, current_user: User, db: AsyncSession) -> Listing:
    result = await db.execute(select(Listing).options(selectinload(Listing.photos)).where(Listing.id == listing_id))
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")
    if listing.host_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your listing")
    return listing


@router.patch("/{listing_id}", response_model=ListingOut)
async def update_listing(
    listing_id: uuid.UUID,
    payload: ListingUpdate,
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> Listing:
    listing = await _get_owned_listing(listing_id, current_user, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(listing, field, value)
    await db.commit()
    await db.refresh(listing, attribute_names=["photos"])
    return listing


@router.delete("/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_listing(
    listing_id: uuid.UUID,
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> None:
    listing = await _get_owned_listing(listing_id, current_user, db)
    await db.delete(listing)
    await db.commit()


@router.post("/{listing_id}/photos", response_model=ListingPhotoOut, status_code=status.HTTP_201_CREATED)
async def upload_listing_photo(
    listing_id: uuid.UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> ListingPhoto:
    listing = await _get_owned_listing(listing_id, current_user, db)
    url = await save_upload(file, "listing-photos")
    photo = ListingPhoto(listing_id=listing.id, url=url, position=len(listing.photos))
    db.add(photo)
    await db.commit()
    await db.refresh(photo)
    return photo
