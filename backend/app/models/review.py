import uuid

from sqlalchemy import ForeignKey, Integer, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class Review(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "reviews"

    booking_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("bookings.id"), unique=True, index=True)
    listing_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("listings.id"), index=True)
    guest_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)

    cleanliness: Mapped[int] = mapped_column(Integer)
    communication: Mapped[int] = mapped_column(Integer)
    accuracy: Mapped[int] = mapped_column(Integer)
    location_rating: Mapped[int] = mapped_column(Integer)
    value: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)

    booking = relationship("Booking", back_populates="review")
    listing = relationship("Listing")
    guest = relationship("User")
