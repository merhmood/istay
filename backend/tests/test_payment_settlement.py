"""The shared settle logic behind both /payments/verify and the webhook."""

from datetime import date, datetime, timezone

from app.api.v1.payments import _apply_verification
from app.models.booking import Booking, BookingStatus
from app.models.payment import Payment, PaymentStatus


def _pair(amount=50000):
    payment = Payment(reference="stn_x", amount=amount, currency="NGN", status=PaymentStatus.INITIALIZED)
    booking = Booking(check_in=date(2026, 3, 10), status=BookingStatus.AWAITING_PAYMENT)
    return payment, booking


def test_successful_full_payment_confirms_booking_and_sets_escrow_release():
    payment, booking = _pair()
    _apply_verification(payment, booking, {"status": "successful", "amount": 50000, "currency": "NGN"})
    assert payment.status == PaymentStatus.SUCCESS
    assert booking.status == BookingStatus.CONFIRMED
    assert booking.payout_release_at == datetime(2026, 3, 11, tzinfo=timezone.utc)


def test_underpayment_is_not_accepted():
    payment, booking = _pair()
    _apply_verification(payment, booking, {"status": "successful", "amount": 100, "currency": "NGN"})
    assert payment.status == PaymentStatus.FAILED
    assert booking.status == BookingStatus.AWAITING_PAYMENT


def test_wrong_currency_is_not_accepted():
    payment, booking = _pair()
    _apply_verification(payment, booking, {"status": "successful", "amount": 50000, "currency": "USD"})
    assert payment.status == PaymentStatus.FAILED


def test_failed_status_marks_payment_failed():
    payment, booking = _pair()
    _apply_verification(payment, booking, {"status": "failed", "amount": 50000, "currency": "NGN"})
    assert payment.status == PaymentStatus.FAILED
    assert booking.status == BookingStatus.AWAITING_PAYMENT


def test_already_successful_payment_is_never_downgraded_or_restamped():
    payment, booking = _pair()
    _apply_verification(payment, booking, {"status": "successful", "amount": 50000, "currency": "NGN"})
    first_release = booking.payout_release_at
    _apply_verification(payment, booking, {"status": "failed", "amount": 0, "currency": "NGN"})
    assert payment.status == PaymentStatus.SUCCESS
    assert booking.status == BookingStatus.CONFIRMED
    assert booking.payout_release_at == first_release
