import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class InteractionKind:
    """The browsing signals worth learning from.

    Bookings and favourites already live in their own tables; these are the
    lighter-weight actions that happen far more often and, together, say more
    about taste than the handful of bookings a guest ever makes.
    """

    # Opened the listing detail screen.
    VIEW = "view"
    # Tapped the listing's marker on the Explore map.
    MAP_VIEW = "map_view"
    # Asked how to get there - opened Bolt, Uber, inDrive or Google Maps.
    DIRECTIONS = "directions"

    ALL = frozenset({VIEW, MAP_VIEW, DIRECTIONS})


class ListingInteraction(UUIDMixin, TimestampMixin, Base):
    """One lightweight engagement event.

    Rows are appended, never deduplicated: coming back to the same listing three
    times is real signal that a single row would throw away. The repeat is damped
    when the taste profile is built rather than at write time, so the raw history
    stays available for anything we want to measure later.

    `user_id` is nullable because browsing without an account is supported. Those
    rows still count toward what is trending, and become attributable if that
    person later signs up on the same device.
    """

    __tablename__ = "listing_interactions"
    __table_args__ = (
        Index("ix_listing_interactions_user_created", "user_id", "created_at"),
        Index("ix_listing_interactions_listing_kind", "listing_id", "kind"),
    )

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True
    )
    # Stable per-install identifier, so signed-out browsing is not simply lost.
    anonymous_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[str] = mapped_column(String(24))
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    listing = relationship("Listing")
