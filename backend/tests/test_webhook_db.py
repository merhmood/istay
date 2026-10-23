"""Webhook end-to-end against a real database (skipped without TEST_DATABASE_URL)."""

from datetime import date

import pytest_asyncio

from app.api.v1 import payments
from app.core.security import hash_password
from app.models.booking import Booking, BookingStatus
from app.models.listing import Listing
from app.models.payment import Payment, PaymentStatus
from app.models.user import User

HEADERS = {"verif-hash": "test-hash"}


@pytest_asyncio.fixture
async def pending_payment(db_session):
    host = User(full_name="H", email="h@x.com", hashed_password=hash_password("pw123456"), is_host=True)
    guest = User(full_name="G", email="g@x.com", hashed_password=hash_password("pw123456"))
    db_session.add_all([host, guest])
    await db_session.flush()
    listing = Listing(
        host_id=host.id, title="T", description="D", city="Abuja", neighborhood_landmark="L",
        latitude=9.0, longitude=7.4, property_type="shortlet_apartment", nightly_rate=20000,
        amenities=[],
    )
    db_session.add(listing)
    await db_session.flush()
    booking = Booking(
        listing_id=listing.id, guest_id=guest.id, host_id=host.id,
        check_in=date(2026, 6, 1), check_out=date(2026, 6, 3), num_guests=1, nights=2,
        subtotal=40000, discount_amount=0, cleaning_fee=0, platform_fee=1400,
        host_payout_amount=38600, total_price=40000, status=BookingStatus.AWAITING_PAYMENT,
    )
    db_session.add(booking)
    await db_session.flush()
    payment = Payment(booking_id=booking.id, reference="stn_abc", amount=40000, status=PaymentStatus.INITIALIZED)
    db_session.add(payment)
    await db_session.commit()
    return booking, payment


async def test_webhook_confirms_booking_without_client_call(client, db_session, pending_payment, monkeypatch):
    booking, payment = pending_payment

    async def fake_verify(ref):
        assert ref == "stn_abc"
        return {"status": "successful", "amount": 40000, "currency": "NGN"}

    monkeypatch.setattr(payments, "verify_transaction", fake_verify)
    r = await client.post("/api/v1/payments/webhook", json={"data": {"tx_ref": "stn_abc"}}, headers=HEADERS)
    assert r.status_code == 200

    await db_session.refresh(booking)
    await db_session.refresh(payment)
    assert booking.status == BookingStatus.CONFIRMED
    assert payment.status == PaymentStatus.SUCCESS


async def test_webhook_ignores_unknown_reference(client, pending_payment):
    r = await client.post("/api/v1/payments/webhook", json={"data": {"tx_ref": "nope"}}, headers=HEADERS)
    assert r.status_code == 200
    assert r.json() == {"status": "ignored"}


async def test_webhook_does_not_trust_body_when_flutterwave_says_failed(client, db_session, pending_payment, monkeypatch):
    booking, _ = pending_payment

    async def fake_verify(ref):
        return {"status": "failed", "amount": 40000, "currency": "NGN"}

    monkeypatch.setattr(payments, "verify_transaction", fake_verify)
    body = {"event": "charge.completed", "data": {"tx_ref": "stn_abc", "status": "successful"}}
    r = await client.post("/api/v1/payments/webhook", json=body, headers=HEADERS)
    assert r.status_code == 200
    await db_session.refresh(booking)
    assert booking.status == BookingStatus.AWAITING_PAYMENT
