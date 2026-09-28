"""One-off: add the newer demo photo URLs to listings that were seeded before they existed."""
import asyncio

from sqlalchemy import select

from app.db.session import AsyncSessionLocal
from app.models.listing import Listing, ListingPhoto
from seed import DEMO_PHOTO_URLS


async def backfill() -> None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Listing))
        listings = result.scalars().all()
        for listing in listings:
            existing = await db.execute(select(ListingPhoto).where(ListingPhoto.listing_id == listing.id))
            existing_urls = {p.url for p in existing.scalars().all()}
            next_position = len(existing_urls)
            for url in DEMO_PHOTO_URLS:
                if url not in existing_urls:
                    db.add(ListingPhoto(listing_id=listing.id, url=url, position=next_position))
                    next_position += 1
        await db.commit()
        print(f"Backfilled photos for {len(listings)} listings.")


if __name__ == "__main__":
    asyncio.run(backfill())
