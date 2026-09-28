import uuid

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class Conversation(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "conversations"

    listing_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("listings.id"), index=True)
    guest_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    host_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)

    listing = relationship("Listing")
    guest = relationship("User", foreign_keys=[guest_id])
    host = relationship("User", foreign_keys=[host_id])
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan", order_by="Message.created_at")


class Message(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "messages"

    conversation_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("conversations.id"), index=True)
    sender_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    body: Mapped[str] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    conversation = relationship("Conversation", back_populates="messages")
    sender = relationship("User")
