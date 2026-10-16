"""Seed demo bookings + payments for the guest account, so the Payments and
Escrow screens have something to render without going through Flutterwave checkout.

One booking is still in escrow (payout releases in the future) and one has
already been released, which exercises both states.

Run with: python seed_payments.py  (after seed.py)
"""
import asyncio
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select

from app.db.session import AsyncSessionLocal
from app.models.booking import Booking, BookingStatus
from app.models.listing import Listing
from app.models.payment import Payment, PaymentStatus
from app.models.user import User

GUEST_EMAIL = "guest@staynaija.demo"


async def seed_payments() -> None:
    async with AsyncSessionLocal() as db:
        guest = (await db.execute(select(User).where(User.email == GUEST_EMAIL))).scalar_one_or_none()
        if not guest:
            print(f"No {GUEST_EMAIL} user - run seed.py first.")
            return

        listings = (await db.execute(select(Listing).limit(2))).scalars().all()
        if not listings:
            print("No listings - run seed.py first.")
            return

        existing = (
            await db.execute(select(Payment).join(Booking).where(Booking.guest_id == guest.id))
        ).scalars().first()
        if existing:
            print("Demo payments already present - nothing to do.")
            return

        today = date.today()
        now = datetime.now(timezone.utc)

        # (listing, check_in offset, nights, payout_release_at) - the first is
        # still held in escrow, the second was released after a past stay.
        specs = [
            (listings[0], 5, 3, now + timedelta(days=6)),
            (listings[-1], -20, 2, now - timedelta(days=18)),
        ]

        for listing, check_in_offset, nights, release_at in specs:
            check_in = today + timedelta(days=check_in_offset)
            subtotal = float(listing.nightly_rate) * nights
            platform_fee = round(subtotal * 0.12, 2)
            total = round(subtotal + platform_fee, 2)

            booking = Booking(
                listing_id=listing.id,
                guest_id=guest.id,
                host_id=listing.host_id,
                check_in=check_in,
                check_out=check_in + timedelta(days=nights),
                num_guests=2,
                nights=nights,
                subtotal=subtotal,
                platform_fee=platform_fee,
                host_payout_amount=subtotal,
                total_price=total,
                status=BookingStatus.CONFIRMED if release_at > now else BookingStatus.COMPLETED,
                payout_release_at=release_at,
            )
            db.add(booking)
            await db.flush()

            reference = f"stn_demo_{uuid.uuid4().hex[:14]}"
            booking.payment_reference = reference
            db.add(
                Payment(
                    booking_id=booking.id,
                    reference=reference,
                    amount=total,
                    status=PaymentStatus.SUCCESS,
                )
            )

        await db.commit()
        print(f"Seeded {len(specs)} demo payments for {GUEST_EMAIL} (1 in escrow, 1 released).")


if __name__ == "__main__":
    asyncio.run(seed_payments())
