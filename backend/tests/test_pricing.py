from datetime import date
from types import SimpleNamespace

import pytest

from app.services.pricing import compute_price_breakdown


def _listing(**overrides):
    base = dict(
        nightly_rate=20000,
        weekly_discount_percent=10,
        monthly_discount_percent=20,
        cleaning_fee=5000,
        minimum_nights=1,
    )
    return SimpleNamespace(**{**base, **overrides})


def test_short_stay_has_no_discount():
    b = compute_price_breakdown(_listing(), date(2026, 1, 1), date(2026, 1, 4))
    assert b.nights == 3
    assert b.subtotal == 60000
    assert b.discount_amount == 0
    assert b.total_price == 65000  # stay + cleaning, nothing added on top


def test_weekly_discount_applies_from_seven_nights():
    b = compute_price_breakdown(_listing(), date(2026, 1, 1), date(2026, 1, 8))
    assert b.discount_amount == 14000
    assert b.total_price == 140000 - 14000 + 5000


def test_monthly_discount_beats_weekly():
    b = compute_price_breakdown(_listing(), date(2026, 1, 1), date(2026, 1, 29))
    assert b.nights == 28
    assert b.discount_amount == 28 * 20000 * 0.20


def test_commission_comes_out_of_host_payout_not_guest_total():
    b = compute_price_breakdown(_listing(weekly_discount_percent=0), date(2026, 1, 1), date(2026, 1, 3))
    assert b.platform_fee == 1400.0  # 3.5% of 40000
    assert b.host_payout_amount == 40000 - 1400
    assert b.total_price == 45000


def test_rejects_non_positive_stay():
    with pytest.raises(ValueError):
        compute_price_breakdown(_listing(), date(2026, 1, 1), date(2026, 1, 1))


def test_enforces_minimum_nights():
    with pytest.raises(ValueError, match="minimum stay of 28 nights"):
        compute_price_breakdown(_listing(minimum_nights=28), date(2026, 1, 1), date(2026, 1, 5))
