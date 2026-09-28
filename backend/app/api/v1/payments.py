import uuid
from datetime import datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.models.booking import Booking, BookingStatus
from app.models.payment import Payment, PaymentStatus
from app.models.listing import Listing
from app.models.user import User
from app.schemas.payment import (
    PaymentHistoryOut,
    PaymentInitializeRequest,
    PaymentInitializeResponse,
    PaymentVerifyRequest,
)
from app.schemas.booking import BookingOut
from app.services.paystack import PaystackError, initialize_transaction, verify_transaction

router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("/initialize", response_model=PaymentInitializeResponse)
async def initialize_payment(
    payload: PaymentInitializeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaymentInitializeResponse:
    result = await db.execute(select(Booking).where(Booking.id == payload.booking_id))
    booking = result.scalar_one_or_none()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.guest_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking")
    if booking.status != BookingStatus.AWAITING_PAYMENT:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking is not awaiting payment")

    reference = f"stn_{uuid.uuid4().hex[:20]}"

    try:
        paystack_data = await initialize_transaction(current_user.email, float(booking.total_price), reference)
    except PaystackError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    booking.paystack_reference = reference
    payment = Payment(
        booking_id=booking.id,
        reference=reference,
        amount=booking.total_price,
        status=PaymentStatus.INITIALIZED,
        paystack_authorization_url=paystack_data.get("authorization_url"),
    )
    db.add(payment)
    await db.commit()

    return PaymentInitializeResponse(
        reference=reference,
        authorization_url=paystack_data.get("authorization_url", ""),
        public_key=settings.paystack_public_key,
        amount_kobo=int(round(float(booking.total_price) * 100)),
        email=current_user.email,
    )


@router.get("/mine", response_model=list[PaymentHistoryOut])
async def list_my_payments(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PaymentHistoryOut]:
    """Every payment the current user has made as a guest, newest first."""
    result = await db.execute(
        select(Payment, Booking, Listing)
        .join(Booking, Payment.booking_id == Booking.id)
        .join(Listing, Booking.listing_id == Listing.id)
        .where(Booking.guest_id == current_user.id)
        .order_by(Payment.created_at.desc())
    )

    now = datetime.now(timezone.utc)
    history: list[PaymentHistoryOut] = []
    for payment, booking, listing in result.all():
        release_at = booking.payout_release_at
        history.append(
            PaymentHistoryOut(
                id=payment.id,
                reference=payment.reference,
                amount=float(payment.amount),
                currency=payment.currency,
                status=payment.status.value,
                created_at=payment.created_at,
                booking_id=booking.id,
                booking_status=booking.status.value,
                listing_title=listing.title,
                listing_city=listing.city,
                check_in=booking.check_in,
                check_out=booking.check_out,
                payout_release_at=release_at,
                in_escrow=(
                    payment.status == PaymentStatus.SUCCESS
                    and release_at is not None
                    and release_at > now
                ),
            )
        )
    return history


@router.post("/verify", response_model=BookingOut)
async def verify_payment(
    payload: PaymentVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Booking:
    result = await db.execute(select(Payment).where(Payment.reference == payload.reference))
    payment = result.scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")

    booking_result = await db.execute(select(Booking).where(Booking.id == payment.booking_id))
    booking = booking_result.scalar_one_or_none()
    if not booking or booking.guest_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking")

    try:
        verification = await verify_transaction(payload.reference)
    except PaystackError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    if verification.get("status") == "success":
        payment.status = PaymentStatus.SUCCESS
        booking.status = BookingStatus.CONFIRMED
        # Escrow-style hold: payout is releasable 24h after check-in, per the PRD's
        # fraud-prevention requirement. No automated payout job exists yet - this
        # timestamp is what a future payout worker would check.
        check_in_start = datetime.combine(booking.check_in, time.min, tzinfo=timezone.utc)
        booking.payout_release_at = check_in_start + timedelta(hours=24)
    else:
        payment.status = PaymentStatus.FAILED

    await db.commit()
    await db.refresh(booking)
    return booking
