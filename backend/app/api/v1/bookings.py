import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.booking import Booking, BookingStatus
from app.models.listing import AvailabilityBlock, Listing
from app.models.user import User
from app.schemas.booking import BookingCreate, BookingOut, BookingStatusUpdate, PriceBreakdown
from app.services.pricing import compute_price_breakdown

router = APIRouter(prefix="/bookings", tags=["bookings"])


async def _get_listing_or_404(listing_id: uuid.UUID, db: AsyncSession) -> Listing:
    result = await db.execute(select(Listing).where(Listing.id == listing_id))
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")
    return listing


async def _has_conflict(listing_id: uuid.UUID, check_in, check_out, db: AsyncSession) -> bool:
    blocked = await db.execute(
        select(AvailabilityBlock).where(
            AvailabilityBlock.listing_id == listing_id,
            AvailabilityBlock.is_blocked.is_(True),
            AvailabilityBlock.start_date < check_out,
            AvailabilityBlock.end_date > check_in,
        )
    )
    if blocked.scalar_one_or_none():
        return True

    active_statuses = [BookingStatus.PENDING_HOST_APPROVAL, BookingStatus.AWAITING_PAYMENT, BookingStatus.CONFIRMED]
    existing = await db.execute(
        select(Booking).where(
            Booking.listing_id == listing_id,
            Booking.status.in_(active_statuses),
            Booking.check_in < check_out,
            Booking.check_out > check_in,
        )
    )
    return existing.scalar_one_or_none() is not None


@router.get("/price-breakdown", response_model=PriceBreakdown)
async def get_price_breakdown(
    listing_id: uuid.UUID,
    check_in: str,
    check_out: str,
    db: AsyncSession = Depends(get_db),
) -> PriceBreakdown:
    from datetime import date

    listing = await _get_listing_or_404(listing_id, db)
    try:
        return compute_price_breakdown(listing, date.fromisoformat(check_in), date.fromisoformat(check_out))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
async def create_booking(
    payload: BookingCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Booking:
    listing = await _get_listing_or_404(payload.listing_id, db)
    if listing.host_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot book your own listing")
    if payload.num_guests > listing.max_guests:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Exceeds max guests for this listing")

    try:
        breakdown = compute_price_breakdown(listing, payload.check_in, payload.check_out)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if await _has_conflict(listing.id, payload.check_in, payload.check_out, db):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Listing not available for these dates")

    initial_status = BookingStatus.AWAITING_PAYMENT if listing.instant_book else BookingStatus.PENDING_HOST_APPROVAL

    booking = Booking(
        listing_id=listing.id,
        guest_id=current_user.id,
        host_id=listing.host_id,
        check_in=payload.check_in,
        check_out=payload.check_out,
        num_guests=payload.num_guests,
        nights=breakdown.nights,
        subtotal=breakdown.subtotal,
        discount_amount=breakdown.discount_amount,
        cleaning_fee=breakdown.cleaning_fee,
        platform_fee=breakdown.platform_fee,
        host_payout_amount=breakdown.host_payout_amount,
        total_price=breakdown.total_price,
        status=initial_status,
    )
    db.add(booking)
    await db.commit()
    await db.refresh(booking)
    return booking


@router.get("/mine", response_model=list[BookingOut])
async def my_bookings(
    as_host: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Booking]:
    column = Booking.host_id if as_host else Booking.guest_id
    result = await db.execute(select(Booking).where(column == current_user.id).order_by(Booking.created_at.desc()))
    return list(result.scalars().all())


async def _get_booking_or_404(booking_id: uuid.UUID, db: AsyncSession) -> Booking:
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    return booking


@router.get("/{booking_id}", response_model=BookingOut)
async def get_booking(
    booking_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Booking:
    booking = await _get_booking_or_404(booking_id, db)
    if current_user.id not in (booking.guest_id, booking.host_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking")
    return booking


@router.patch("/{booking_id}/status", response_model=BookingOut)
async def update_booking_status(
    booking_id: uuid.UUID,
    payload: BookingStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Booking:
    booking = await _get_booking_or_404(booking_id, db)

    is_host_action = payload.status in (BookingStatus.CONFIRMED, BookingStatus.DECLINED)
    is_cancel_action = payload.status == BookingStatus.CANCELLED

    if is_host_action:
        if current_user.id != booking.host_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the host can accept/decline")
        if booking.status != BookingStatus.PENDING_HOST_APPROVAL:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking is not pending approval")
        if payload.status == BookingStatus.CONFIRMED:
            booking.status = BookingStatus.AWAITING_PAYMENT
        else:
            booking.status = BookingStatus.DECLINED
    elif is_cancel_action:
        if current_user.id not in (booking.guest_id, booking.host_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking")
        if booking.status == BookingStatus.CONFIRMED:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Confirmed bookings cannot be self-cancelled")
        booking.status = BookingStatus.CANCELLED
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported status transition")

    await db.commit()
    await db.refresh(booking)
    return booking
