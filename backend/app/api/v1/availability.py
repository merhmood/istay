import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_host
from app.db.session import get_db
from app.models.listing import AvailabilityBlock, Listing
from app.models.user import User
from app.schemas.listing import AvailabilityBlockCreate, AvailabilityBlockOut

router = APIRouter(prefix="/listings/{listing_id}/availability", tags=["availability"])


async def _get_owned_listing(listing_id: uuid.UUID, current_user: User, db: AsyncSession) -> Listing:
    result = await db.execute(select(Listing).where(Listing.id == listing_id))
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")
    if listing.host_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your listing")
    return listing


@router.get("", response_model=list[AvailabilityBlockOut])
async def list_availability_blocks(
    listing_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
) -> list[AvailabilityBlock]:
    result = await db.execute(select(AvailabilityBlock).where(AvailabilityBlock.listing_id == listing_id))
    return list(result.scalars().all())


@router.post("", response_model=AvailabilityBlockOut, status_code=status.HTTP_201_CREATED)
async def create_availability_block(
    listing_id: uuid.UUID,
    payload: AvailabilityBlockCreate,
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> AvailabilityBlock:
    await _get_owned_listing(listing_id, current_user, db)
    block = AvailabilityBlock(listing_id=listing_id, **payload.model_dump())
    db.add(block)
    await db.commit()
    await db.refresh(block)
    return block


@router.delete("/{block_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_availability_block(
    listing_id: uuid.UUID,
    block_id: uuid.UUID,
    current_user: User = Depends(get_current_host),
    db: AsyncSession = Depends(get_db),
) -> None:
    await _get_owned_listing(listing_id, current_user, db)
    result = await db.execute(
        select(AvailabilityBlock).where(AvailabilityBlock.id == block_id, AvailabilityBlock.listing_id == listing_id)
    )
    block = result.scalar_one_or_none()
    if not block:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Block not found")
    await db.delete(block)
    await db.commit()
