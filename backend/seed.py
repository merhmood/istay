"""Seed a couple of demo users and listings so the Flutter app has data to show.

Run with: python seed.py  (after `alembic upgrade head`)
"""
import asyncio

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.listing import Listing, ListingPhoto
from app.models.user import User

# Unsplash serves the raw photo (~1MB each) unless you ask for a size. At 8
# photos per listing that swamped the phone's connection and left carousels
# blank, so every URL carries explicit resize/quality params (~95KB each).
_UNSPLASH_PARAMS = "?w=800&q=75&auto=format&fit=crop"

DEMO_PHOTO_URLS = [
    f"https://images.unsplash.com/{photo_id}{_UNSPLASH_PARAMS}"
    for photo_id in [
        "photo-1502672260266-1c1ef2d93688",
        "photo-1522708323590-d24dbb6b0267",
        "photo-1484154218962-a197022b5858",
        "photo-1493809842364-78817add7ffb",
        "photo-1560448204-e02f11c3d0e2",
        "photo-1560185127-6ed189bf02f4",
        "photo-1560449017-7fedf323ecdf",
        "photo-1512918728675-ed5a9ecdebfd",
    ]
]


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.email == "host@staynaija.demo"))
        host = result.scalar_one_or_none()
        if not host:
            host = User(
                full_name="Adaeze Okafor",
                email="host@staynaija.demo",
                hashed_password=hash_password("password123"),
                phone_number="+2348012345678",
                is_host=True,
                phone_verified=True,
                email_verified=True,
                verification_status="verified",
            )
            db.add(host)
            await db.flush()

        result = await db.execute(select(User).where(User.email == "guest@staynaija.demo"))
        guest = result.scalar_one_or_none()
        if not guest:
            guest = User(
                full_name="Chinedu Eze",
                email="guest@staynaija.demo",
                hashed_password=hash_password("password123"),
                phone_number="+2348098765432",
                phone_verified=True,
                email_verified=True,
            )
            db.add(guest)

        result = await db.execute(select(User).where(User.email == "admin@staynaija.demo"))
        if not result.scalar_one_or_none():
            db.add(
                User(
                    full_name="StayNaija Ops",
                    email="admin@staynaija.demo",
                    hashed_password=hash_password("password123"),
                    is_admin=True,
                    phone_verified=True,
                    email_verified=True,
                )
            )

        # A second host, sitting in the verification queue, so the admin
        # approval screen has something to review without waiting on a real
        # document upload from a device.
        result = await db.execute(select(User).where(User.email == "pending-host@staynaija.demo"))
        if not result.scalar_one_or_none():
            db.add(
                User(
                    full_name="Ifeoma Nwosu",
                    email="pending-host@staynaija.demo",
                    hashed_password=hash_password("password123"),
                    phone_number="+2348055501234",
                    is_host=True,
                    phone_verified=True,
                    email_verified=True,
                    verification_status="pending",
                    id_document_url=f"https://images.unsplash.com/photo-1544376798-89aa6b82c6ff{_UNSPLASH_PARAMS}",
                    selfie_url=f"https://images.unsplash.com/photo-1633332755192-727a05c4013d{_UNSPLASH_PARAMS}",
                )
            )

        existing_listings = await db.execute(select(Listing).where(Listing.host_id == host.id))
        if not existing_listings.scalars().first():
            listings_data = [
                dict(
                    title="Modern 2-Bed Apartment in Lekki Phase 1",
                    description="Bright, fully serviced apartment minutes from the Lekki-Epe expressway. Great for business travelers.",
                    city="Lagos",
                    neighborhood_landmark="Behind Shoprite Lekki",
                    latitude=6.4413,
                    longitude=3.4732,
                    property_type="shortlet_apartment",
                    bedrooms=2,
                    bathrooms=2,
                    max_guests=4,
                    nightly_rate=55000,
                    weekly_discount_percent=10,
                    monthly_discount_percent=25,
                    cleaning_fee=5000,
                    amenities=["wifi", "parking", "ac", "kitchen"],
                    has_generator=True,
                    has_inverter=True,
                    is_gated_estate=True,
                    has_security_guard=True,
                    has_cctv=True,
                    instant_book=True,
                ),
                dict(
                    title="Cozy Studio near Wuse II, Abuja",
                    description="Compact studio ideal for solo travelers and remote workers, walking distance to Wuse market.",
                    city="Abuja",
                    neighborhood_landmark="Close to Next Cash & Carry, Wuse II",
                    latitude=9.0765,
                    longitude=7.4951,
                    property_type="shortlet_apartment",
                    bedrooms=1,
                    bathrooms=1,
                    max_guests=2,
                    nightly_rate=30000,
                    weekly_discount_percent=8,
                    monthly_discount_percent=20,
                    cleaning_fee=3000,
                    amenities=["wifi", "ac"],
                    has_generator=True,
                    has_24hr_electricity=True,
                    is_gated_estate=True,
                    instant_book=False,
                ),
                dict(
                    title="Luxury 3-Bed Duplex, GRA Port Harcourt",
                    description="Spacious duplex with pool access, perfect for events and family stays.",
                    city="Port Harcourt",
                    neighborhood_landmark="Off Aba Road, opposite Genesis Cinema",
                    latitude=4.8156,
                    longitude=7.0498,
                    property_type="vacation_rental",
                    bedrooms=3,
                    bathrooms=3,
                    max_guests=6,
                    nightly_rate=95000,
                    weekly_discount_percent=12,
                    monthly_discount_percent=30,
                    cleaning_fee=8000,
                    amenities=["wifi", "parking", "pool", "ac", "kitchen"],
                    has_generator=True,
                    has_inverter=True,
                    has_24hr_electricity=True,
                    is_gated_estate=True,
                    has_security_guard=True,
                    has_cctv=True,
                    instant_book=True,
                ),
            ]
            for data in listings_data:
                listing = Listing(host_id=host.id, **data)
                db.add(listing)
                await db.flush()
                for i, url in enumerate(DEMO_PHOTO_URLS):
                    db.add(ListingPhoto(listing_id=listing.id, url=url, position=i))

        await db.commit()
        print(
            "Seed complete. Demo logins (password: password123): "
            "guest@staynaija.demo / host@staynaija.demo / admin@staynaija.demo / pending-host@staynaija.demo"
        )


if __name__ == "__main__":
    asyncio.run(seed())
