import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.favorite import Favorite
from app.models.listing import Listing
from app.models.user import User
from app.schemas.favorite import FavoriteListingIds
from app.schemas.listing import ListingOut

router = APIRouter(prefix="/favorites", tags=["favorites"])


@router.get("", response_model=list[ListingOut])
async def list_favorites(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> list[Listing]:
    result = await db.execute(
        select(Listing)
        .join(Favorite, Favorite.listing_id == Listing.id)
        .options(selectinload(Listing.photos))
        .where(Favorite.user_id == current_user.id)
        .order_by(Favorite.created_at.desc())
    )
    return list(result.scalars().all())


@router.get("/ids", response_model=FavoriteListingIds)
async def list_favorite_ids(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> FavoriteListingIds:
    result = await db.execute(select(Favorite.listing_id).where(Favorite.user_id == current_user.id))
    return FavoriteListingIds(listing_ids=list(result.scalars().all()))


@router.post("/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def add_favorite(
    listing_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    listing_result = await db.execute(select(Listing).where(Listing.id == listing_id))
    if not listing_result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")

    db.add(Favorite(user_id=current_user.id, listing_id=listing_id))
    try:
        await db.commit()
    except IntegrityError:
        # Already favorited - treat as a no-op success.
        await db.rollback()


@router.delete("/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite(
    listing_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(Favorite).where(Favorite.user_id == current_user.id, Favorite.listing_id == listing_id)
    )
    favorite = result.scalar_one_or_none()
    if favorite:
        await db.delete(favorite)
        await db.commit()
