import uuid

from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class Favorite(UUIDMixin, TimestampMixin, Base):
    """A guest's saved/wishlisted listing."""

    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("user_id", "listing_id", name="uq_favorites_user_listing"),)

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    listing_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("listings.id"), index=True)

    listing = relationship("Listing")
