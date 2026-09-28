import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ConversationCreate(BaseModel):
    listing_id: uuid.UUID


class MessageCreate(BaseModel):
    body: str
    image_url: str | None = None


class MessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    conversation_id: uuid.UUID
    sender_id: uuid.UUID
    body: str
    image_url: str | None
    created_at: datetime


class ConversationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    listing_id: uuid.UUID
    guest_id: uuid.UUID
    host_id: uuid.UUID
    created_at: datetime


class ConversationSummaryOut(BaseModel):
    """A conversation enriched with the other participant's identity and the
    latest message, for rendering an inbox-style list without an extra round trip
    per conversation."""

    id: uuid.UUID
    listing_id: uuid.UUID
    other_user_name: str
    other_user_avatar_url: str | None
    last_message_body: str | None
    last_message_at: datetime | None
    created_at: datetime
