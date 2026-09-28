import uuid

from pydantic import BaseModel


class FavoriteListingIds(BaseModel):
    listing_ids: list[uuid.UUID]
