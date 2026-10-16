import uuid
from datetime import date, datetime

from pydantic import BaseModel


class PaymentInitializeRequest(BaseModel):
    booking_id: uuid.UUID


class PaymentInitializeResponse(BaseModel):
    reference: str
    checkout_url: str
    email: str


class PaymentVerifyRequest(BaseModel):
    reference: str


class PaymentHistoryOut(BaseModel):
    """One payment, flattened with the booking/listing context the app needs so
    the payments and escrow screens don't have to fan out N extra requests."""

    id: uuid.UUID
    reference: str
    amount: float
    currency: str
    status: str
    created_at: datetime

    booking_id: uuid.UUID
    booking_status: str
    listing_title: str
    listing_city: str
    check_in: date
    check_out: date

    payout_release_at: datetime | None
    # True while a successful payment is still being held: the guest has paid but
    # the host payout window (check-in + 24h) hasn't elapsed.
    in_escrow: bool
