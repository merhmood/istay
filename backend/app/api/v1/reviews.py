import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.booking import Booking, BookingStatus
from app.models.review import Review
from app.models.user import User
from app.schemas.review import ReviewCreate, ReviewOut

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.post("", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def create_review(
    payload: ReviewCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Review:
    result = await db.execute(select(Booking).where(Booking.id == payload.booking_id))
    booking = result.scalar_one_or_none()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.guest_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the guest can review this stay")
    if booking.status != BookingStatus.COMPLETED:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking must be completed before reviewing")

    existing = await db.execute(select(Review).where(Review.booking_id == booking.id))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This stay has already been reviewed")

    review = Review(
        booking_id=booking.id,
        listing_id=booking.listing_id,
        guest_id=current_user.id,
        cleanliness=payload.cleanliness,
        communication=payload.communication,
        accuracy=payload.accuracy,
        location_rating=payload.location_rating,
        value=payload.value,
        comment=payload.comment,
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)
    return review


@router.get("/listing/{listing_id}", response_model=list[ReviewOut])
async def list_listing_reviews(listing_id: uuid.UUID, db: AsyncSession = Depends(get_db)) -> list[Review]:
    result = await db.execute(select(Review).where(Review.listing_id == listing_id).order_by(Review.created_at.desc()))
    return list(result.scalars().all())
