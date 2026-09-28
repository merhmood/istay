import uuid
from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class Listing(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "listings"

    host_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)

    title: Mapped[str] = mapped_column(String(150))
    description: Mapped[str] = mapped_column(Text)

    city: Mapped[str] = mapped_column(String(100), index=True)
    # Nigerian addresses are often unreliable; a landmark description plus a map pin
    # (lat/lng) is used instead of relying on a strict postal address.
    neighborhood_landmark: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float] = mapped_column(Numeric(9, 6))
    longitude: Mapped[float] = mapped_column(Numeric(9, 6))

    property_type: Mapped[str] = mapped_column(String(50))  # apartment, house, studio, etc.
    bedrooms: Mapped[int] = mapped_column(Integer, default=1)
    bathrooms: Mapped[int] = mapped_column(Integer, default=1)
    max_guests: Mapped[int] = mapped_column(Integer, default=2)

    # Always a true per-night amount, regardless of the listing's stay type.
    # A host of a Long stay (billed monthly) or Extended stay (billed weekly)
    # property enters and sees their natural unit in the app; the client
    # converts to/from this nightly-equivalent figure at the boundary (see
    # `stay_type.dart` / `stay_types.py`). This keeps every price calculation
    # in this file and in `services/pricing.py` correct without a special case
    # - `total_price = nightly_rate * nights` is true for every listing.
    nightly_rate: Mapped[float] = mapped_column(Numeric(12, 2))
    weekly_discount_percent: Mapped[float] = mapped_column(Numeric(5, 2), default=0)
    monthly_discount_percent: Mapped[float] = mapped_column(Numeric(5, 2), default=0)
    cleaning_fee: Mapped[float] = mapped_column(Numeric(12, 2), default=0)

    # Shortest booking this listing accepts, in nights. A Long stay quoted and
    # billed monthly makes no sense booked for two nights, so this is enforced
    # at booking time (see api/v1/bookings.py) rather than left as a UI hint.
    minimum_nights: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    # Called out as its own field rather than a generic amenity string because
    # it is the one detail explicitly named in three of the ten stay-type
    # descriptions (hotel, guesthouse/B&B, resort) and is meaningfully
    # different from a fixed amenity like wifi - it changes what a guest
    # expects to pay for separately.
    breakfast_included: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    amenities: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    house_rules: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Nigeria-specific localization filters.
    has_generator: Mapped[bool] = mapped_column(Boolean, default=False)
    has_inverter: Mapped[bool] = mapped_column(Boolean, default=False)
    has_24hr_electricity: Mapped[bool] = mapped_column(Boolean, default=False)
    is_gated_estate: Mapped[bool] = mapped_column(Boolean, default=False)
    has_security_guard: Mapped[bool] = mapped_column(Boolean, default=False)
    has_cctv: Mapped[bool] = mapped_column(Boolean, default=False)

    instant_book: Mapped[bool] = mapped_column(Boolean, default=False)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)

    host = relationship("User", back_populates="listings")
    photos = relationship("ListingPhoto", back_populates="listing", cascade="all, delete-orphan", order_by="ListingPhoto.position")
    availability_blocks = relationship("AvailabilityBlock", back_populates="listing", cascade="all, delete-orphan")


class ListingPhoto(UUIDMixin, Base):
    __tablename__ = "listing_photos"

    listing_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("listings.id"), index=True)
    url: Mapped[str] = mapped_column(String(500))
    position: Mapped[int] = mapped_column(Integer, default=0)

    listing = relationship("Listing", back_populates="photos")


class AvailabilityBlock(UUIDMixin, Base):
    """A date range the host has blocked off (unavailable), or a seasonal price override."""

    __tablename__ = "availability_blocks"

    listing_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("listings.id"), index=True)
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date] = mapped_column(Date)
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=True)
    override_nightly_rate: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)

    listing = relationship("Listing", back_populates="availability_blocks")
