import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ReviewCreate(BaseModel):
    booking_id: uuid.UUID
    cleanliness: int = Field(ge=1, le=5)
    communication: int = Field(ge=1, le=5)
    accuracy: int = Field(ge=1, le=5)
    location_rating: int = Field(ge=1, le=5)
    value: int = Field(ge=1, le=5)
    comment: str | None = None


class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    booking_id: uuid.UUID
    listing_id: uuid.UUID
    guest_id: uuid.UUID
    cleanliness: int
    communication: int
    accuracy: int
    location_rating: int
    value: int
    comment: str | None
    created_at: datetime
