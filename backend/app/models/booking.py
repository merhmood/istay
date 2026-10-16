import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class BookingStatus(str, enum.Enum):
    PENDING_HOST_APPROVAL = "pending_host_approval"
    AWAITING_PAYMENT = "awaiting_payment"
    CONFIRMED = "confirmed"
    DECLINED = "declined"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


class Booking(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "bookings"

    listing_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("listings.id"), index=True)
    guest_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    host_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)

    check_in: Mapped[date] = mapped_column(Date)
    check_out: Mapped[date] = mapped_column(Date)
    num_guests: Mapped[int] = mapped_column(Integer, default=1)

    # Server-computed price breakdown - never trusted from the client.
    nights: Mapped[int] = mapped_column(Integer)
    subtotal: Mapped[float] = mapped_column(Numeric(12, 2))
    discount_amount: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    cleaning_fee: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    platform_fee: Mapped[float] = mapped_column(Numeric(12, 2))
    host_payout_amount: Mapped[float] = mapped_column(Numeric(12, 2))
    total_price: Mapped[float] = mapped_column(Numeric(12, 2))

    status: Mapped[BookingStatus] = mapped_column(
        Enum(BookingStatus, name="booking_status", values_callable=lambda enum_cls: [e.value for e in enum_cls]),
        default=BookingStatus.PENDING_HOST_APPROVAL,
    )

    # Escrow-style hold: funds are considered releasable to the host only after this time
    # (check-in + 24h), per the PRD's fraud-prevention requirement. No real ledger/payout
    # automation is built yet - this is the timestamp a future payout job would check.
    payout_release_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    payment_reference: Mapped[str | None] = mapped_column(String(100), unique=True, nullable=True)

    listing = relationship("Listing")
    guest = relationship("User", foreign_keys=[guest_id])
    host = relationship("User", foreign_keys=[host_id])
    payments = relationship("Payment", back_populates="booking", cascade="all, delete-orphan")
    review = relationship("Review", back_populates="booking", uselist=False)
