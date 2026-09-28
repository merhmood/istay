import enum
import uuid

from sqlalchemy import Enum, ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class PaymentStatus(str, enum.Enum):
    INITIALIZED = "initialized"
    SUCCESS = "success"
    FAILED = "failed"


class Payment(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "payments"

    booking_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("bookings.id"), index=True)
    reference: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(3), default="NGN")
    status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status", values_callable=lambda enum_cls: [e.value for e in enum_cls]),
        default=PaymentStatus.INITIALIZED,
    )
    paystack_authorization_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    paystack_raw_response: Mapped[str | None] = mapped_column(String, nullable=True)

    booking = relationship("Booking", back_populates="payments")
