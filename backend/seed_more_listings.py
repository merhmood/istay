"""Add 20 more demo listings across Lagos, Abuja and Port Harcourt.

Coordinates are real neighbourhood centres so the Explore map and the
neighbourhood/landmark search behave sensibly. Photos are drawn from the same
Unsplash pool as seed.py, rotated per listing so the carousels don't all look
identical.

Run with: python seed_more_listings.py  (after seed.py)
"""
import asyncio

from sqlalchemy import select

from app.db.session import AsyncSessionLocal
from app.models.listing import Listing, ListingPhoto
from app.models.user import User

from seed import DEMO_PHOTO_URLS

HOST_EMAIL = "host@staynaija.demo"

# (title, city, landmark, lat, lng, type, beds, baths, guests, rate, amenities, flags)
# flags: generator, inverter, 24hr, gated, guard, cctv, instant_book
LISTINGS = [
    # ---- Lagos ----
    ("Sunlit 3-Bed Flat in Ikoyi", "Lagos", "Off Awolowo Road, near Falomo Bridge", 6.4541, 3.4348,
     "shortlet_apartment", 3, 3, 6, 145000, ["wifi", "ac", "parking", "kitchen", "washing_machine"],
     (True, True, True, True, True, True, True)),
    ("Serviced Studio in Victoria Island", "Lagos", "Behind Eko Hotel, Adetokunbo Ademola", 6.4281, 3.4219,
     "shortlet_apartment", 1, 1, 2, 78000, ["wifi", "ac", "kitchen", "gym"],
     (True, True, True, True, True, False, True)),
    ("Family Duplex in Ikeja GRA", "Lagos", "Close to Sheraton Hotel, Mobolaji Bank Anthony", 6.5833, 3.3500,
     "vacation_rental", 4, 4, 8, 190000, ["wifi", "ac", "parking", "kitchen", "pool", "bbq"],
     (True, True, False, True, True, True, False)),
    ("Cosy 1-Bed in Yaba Tech Hub", "Lagos", "Opposite Yabatech main gate, Herbert Macaulay", 6.5158, 3.3707,
     "shortlet_apartment", 1, 1, 2, 42000, ["wifi", "ac", "kitchen", "workspace"],
     (True, False, False, False, True, False, True)),
    ("Beachfront Apartment, Oniru", "Lagos", "2 minutes from Landmark Beach", 6.4275, 3.4534,
     "shortlet_apartment", 2, 2, 4, 132000, ["wifi", "ac", "parking", "kitchen", "pool", "beach_access"],
     (True, True, True, True, True, True, True)),
    ("Modern Loft in Lekki Phase 2", "Lagos", "After Chevron roundabout, Orchid Road", 6.4450, 3.5390,
     "shortlet_apartment", 2, 2, 4, 96000, ["wifi", "ac", "parking", "kitchen", "workspace"],
     (True, True, False, True, True, True, True)),
    ("Budget Room in Surulere", "Lagos", "Near National Stadium, Bode Thomas", 6.4969, 3.3481,
     "shortlet_apartment", 1, 1, 2, 28000, ["wifi", "fan", "kitchen"],
     (True, False, False, False, False, False, True)),
    ("Executive 2-Bed in Ajah", "Lagos", "Off Addo Road, close to Thomas Estate", 6.4698, 3.5852,
     "shortlet_apartment", 2, 2, 4, 65000, ["wifi", "ac", "parking", "kitchen"],
     (True, True, False, True, True, False, False)),

    # ---- Abuja ----
    ("Luxury 3-Bed in Maitama", "Abuja", "Off Gana Street, near Transcorp Hilton", 9.0850, 7.4900,
     "shortlet_apartment", 3, 3, 6, 175000, ["wifi", "ac", "parking", "kitchen", "gym", "pool"],
     (True, True, True, True, True, True, True)),
    ("Quiet Studio in Jabi", "Abuja", "Walking distance to Jabi Lake Mall", 9.0640, 7.4270,
     "shortlet_apartment", 1, 1, 2, 52000, ["wifi", "ac", "kitchen", "workspace"],
     (True, True, False, True, True, True, True)),
    ("Spacious Flat in Gwarinpa", "Abuja", "3rd Avenue, near Life Camp junction", 9.1090, 7.4030,
     "shortlet_apartment", 3, 2, 6, 72000, ["wifi", "ac", "parking", "kitchen", "washing_machine"],
     (True, True, False, True, True, False, True)),
    ("Serviced 1-Bed in Wuse 2", "Abuja", "Off Aminu Kano Crescent, near Banex", 9.0760, 7.4650,
     "shortlet_apartment", 1, 1, 2, 68000, ["wifi", "ac", "parking", "kitchen", "gym"],
     (True, True, True, True, True, True, True)),
    ("Affordable Room in Kubwa", "Abuja", "Phase 4, close to FO1 junction", 9.1550, 7.3280,
     "shortlet_apartment", 1, 1, 3, 26000, ["wifi", "fan", "kitchen", "parking"],
     (True, False, False, False, True, False, True)),
    ("Garden Duplex in Asokoro", "Abuja", "Off Yakubu Gowon Crescent", 9.0410, 7.5290,
     "vacation_rental", 4, 4, 8, 210000, ["wifi", "ac", "parking", "kitchen", "pool", "garden", "bbq"],
     (True, True, True, True, True, True, False)),
    ("Compact Apartment in Utako", "Abuja", "Behind Utako Market, off Ekukinam Street", 9.0690, 7.4390,
     "shortlet_apartment", 2, 1, 4, 48000, ["wifi", "ac", "kitchen", "parking"],
     (True, True, False, True, True, False, True)),
    ("City View Flat in Central Area", "Abuja", "Near Millennium Park, Shehu Shagari Way", 9.0580, 7.4890,
     "shortlet_apartment", 2, 2, 4, 105000, ["wifi", "ac", "parking", "kitchen", "gym"],
     (True, True, True, True, True, True, True)),

    # ---- Port Harcourt ----
    ("Elegant 2-Bed in GRA Phase 2", "Port Harcourt", "Off Evo Road, near Genesis Restaurant", 4.8250, 7.0050,
     "shortlet_apartment", 2, 2, 4, 88000, ["wifi", "ac", "parking", "kitchen", "washing_machine"],
     (True, True, True, True, True, True, True)),
    ("Serviced Studio in Trans Amadi", "Port Harcourt", "Close to Trans Amadi Industrial Layout", 4.7910, 7.0340,
     "shortlet_apartment", 1, 1, 2, 45000, ["wifi", "ac", "kitchen", "workspace"],
     (True, True, False, True, True, False, True)),
    ("Family Home in Rumuokoro", "Port Harcourt", "Off Rumuokoro roundabout, East-West Road", 4.8630, 6.9980,
     "vacation_rental", 3, 3, 6, 62000, ["wifi", "ac", "parking", "kitchen", "garden"],
     (True, False, False, True, True, False, False)),
    ("Riverside Apartment in Old GRA", "Port Harcourt", "Near Presidential Hotel, Aba Road", 4.8060, 7.0000,
     "shortlet_apartment", 2, 2, 4, 115000, ["wifi", "ac", "parking", "kitchen", "pool", "gym"],
     (True, True, True, True, True, True, True)),
]


async def seed_more() -> None:
    async with AsyncSessionLocal() as db:
        host = (await db.execute(select(User).where(User.email == HOST_EMAIL))).scalar_one_or_none()
        if not host:
            print(f"No {HOST_EMAIL} user - run seed.py first.")
            return

        existing_titles = set((await db.execute(select(Listing.title))).scalars().all())

        added = 0
        for index, spec in enumerate(LISTINGS):
            (title, city, landmark, lat, lng, prop_type, beds, baths, guests,
             rate, amenities, flags) = spec
            if title in existing_titles:
                continue

            generator, inverter, electricity, gated, guard, cctv, instant = flags
            listing = Listing(
                host_id=host.id,
                title=title,
                description=(
                    f"A well-kept {prop_type} in {city}, {landmark.lower()}. "
                    f"Sleeps up to {guests} guests across {beds} bedroom(s) and {baths} bathroom(s). "
                    "Clean, self-contained and ready for short or extended stays."
                ),
                city=city,
                neighborhood_landmark=landmark,
                latitude=lat,
                longitude=lng,
                property_type=prop_type,
                bedrooms=beds,
                bathrooms=baths,
                max_guests=guests,
                nightly_rate=rate,
                weekly_discount_percent=10 if rate > 60000 else 5,
                monthly_discount_percent=20 if rate > 60000 else 12,
                cleaning_fee=round(rate * 0.08),
                amenities=amenities,
                house_rules="No smoking indoors. No parties. Quiet hours after 10pm.",
                has_generator=generator,
                has_inverter=inverter,
                has_24hr_electricity=electricity,
                is_gated_estate=gated,
                has_security_guard=guard,
                has_cctv=cctv,
                instant_book=instant,
            )
            db.add(listing)
            await db.flush()

            # Rotate the photo pool per listing so carousels differ from each other.
            offset = index % len(DEMO_PHOTO_URLS)
            rotated = DEMO_PHOTO_URLS[offset:] + DEMO_PHOTO_URLS[:offset]
            for position, url in enumerate(rotated):
                db.add(ListingPhoto(listing_id=listing.id, url=url, position=position))
            added += 1

        await db.commit()
        print(f"Added {added} listings ({len(LISTINGS) - added} already existed).")


if __name__ == "__main__":
    asyncio.run(seed_more())
