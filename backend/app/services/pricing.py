from datetime import date

from app.core.config import settings
from app.models.listing import Listing
from app.schemas.booking import PriceBreakdown


def compute_price_breakdown(listing: Listing, check_in: date, check_out: date) -> PriceBreakdown:
    nights = (check_out - check_in).days
    if nights <= 0:
        raise ValueError("check_out must be after check_in")
    if nights < listing.minimum_nights:
        # A Long stay listing quoted per month makes no sense booked for two
        # nights - this is the one place both the price-preview and the actual
        # booking endpoint route through, so the floor is enforced once here
        # rather than duplicated in both callers.
        nights_word = "night" if listing.minimum_nights == 1 else "nights"
        raise ValueError(f"This listing requires a minimum stay of {listing.minimum_nights} {nights_word}")

    nightly_rate = float(listing.nightly_rate)
    subtotal = nightly_rate * nights

    discount_percent = 0.0
    if nights >= 28 and float(listing.monthly_discount_percent) > 0:
        discount_percent = float(listing.monthly_discount_percent)
    elif nights >= 7 and float(listing.weekly_discount_percent) > 0:
        discount_percent = float(listing.weekly_discount_percent)

    discount_amount = round(subtotal * discount_percent / 100, 2)
    cleaning_fee = float(listing.cleaning_fee)

    discounted_subtotal = subtotal - discount_amount
    # Host-only commission: taken out of the host's payout, never added on top
    # of the guest's total - the guest pays exactly the stay price plus
    # cleaning, nothing else. `platform_fee` still travels with the booking so
    # the host app can show what was deducted (see EarningsScreen).
    platform_fee = round(discounted_subtotal * settings.platform_commission_percent / 100, 2)
    host_payout_amount = round(discounted_subtotal - platform_fee, 2)
    total_price = round(discounted_subtotal + cleaning_fee, 2)

    return PriceBreakdown(
        nights=nights,
        nightly_rate=nightly_rate,
        subtotal=round(subtotal, 2),
        discount_amount=discount_amount,
        cleaning_fee=cleaning_fee,
        platform_fee=platform_fee,
        host_payout_amount=host_payout_amount,
        total_price=total_price,
    )
