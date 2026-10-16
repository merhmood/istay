import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.models.booking import BookingStatus


class BookingCreate(BaseModel):
    listing_id: uuid.UUID
    check_in: date
    check_out: date
    num_guests: int = 1


class PriceBreakdown(BaseModel):
    nights: int
    nightly_rate: float
    subtotal: float
    discount_amount: float
    cleaning_fee: float
    platform_fee: float
    host_payout_amount: float
    total_price: float


class BookingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    listing_id: uuid.UUID
    guest_id: uuid.UUID
    host_id: uuid.UUID
    check_in: date
    check_out: date
    num_guests: int
    nights: int
    subtotal: float
    discount_amount: float
    cleaning_fee: float
    platform_fee: float
    host_payout_amount: float
    total_price: float
    status: BookingStatus
    payout_release_at: datetime | None
    payment_reference: str | None


class BookingStatusUpdate(BaseModel):
    status: BookingStatus
