"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-09-12
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Created via raw SQL (create_type=False on the column types below) rather than
    # relying on SQLAlchemy's automatic before_create DDL event, which double-fires
    # CREATE TYPE for a freshly-instantiated Enum in some SQLAlchemy 2.0.x + asyncpg
    # combinations and errors with "type already exists" even on a clean database.
    op.execute(
        "CREATE TYPE booking_status AS ENUM ("
        "'pending_host_approval', 'awaiting_payment', 'confirmed', 'declined', 'cancelled', 'completed')"
    )
    op.execute("CREATE TYPE payment_status AS ENUM ('initialized', 'success', 'failed')")

    booking_status = postgresql.ENUM(
        "pending_host_approval",
        "awaiting_payment",
        "confirmed",
        "declined",
        "cancelled",
        "completed",
        name="booking_status",
        create_type=False,
    )
    payment_status = postgresql.ENUM("initialized", "success", "failed", name="payment_status", create_type=False)

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("full_name", sa.String(150), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("phone_number", sa.String(20), nullable=True),
        sa.Column("is_host", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("phone_verified", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("email_verified", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("verification_status", sa.String(20), nullable=False, server_default="unverified"),
        sa.Column("id_document_url", sa.String(500), nullable=True),
        sa.Column("selfie_url", sa.String(500), nullable=True),
        sa.Column("payout_bank_name", sa.String(100), nullable=True),
        sa.Column("payout_account_number", sa.String(20), nullable=True),
        sa.Column("payout_account_name", sa.String(150), nullable=True),
        sa.Column("avatar_url", sa.String(500), nullable=True),
        sa.Column("otp_code_hash", sa.String(255), nullable=True),
        sa.Column("otp_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("email"),
        sa.UniqueConstraint("phone_number"),
    )
    op.create_index("ix_users_email", "users", ["email"])
    op.create_index("ix_users_phone_number", "users", ["phone_number"])

    op.create_table(
        "listings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("host_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(150), nullable=False),
        sa.Column("description", sa.Text, nullable=False),
        sa.Column("city", sa.String(100), nullable=False),
        sa.Column("neighborhood_landmark", sa.String(255), nullable=False),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("longitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("property_type", sa.String(50), nullable=False),
        sa.Column("bedrooms", sa.Integer, nullable=False, server_default="1"),
        sa.Column("bathrooms", sa.Integer, nullable=False, server_default="1"),
        sa.Column("max_guests", sa.Integer, nullable=False, server_default="2"),
        sa.Column("nightly_rate", sa.Numeric(12, 2), nullable=False),
        sa.Column("weekly_discount_percent", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("monthly_discount_percent", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("cleaning_fee", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("amenities", postgresql.ARRAY(sa.String), nullable=False, server_default="{}"),
        sa.Column("house_rules", sa.Text, nullable=True),
        sa.Column("has_generator", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("has_inverter", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("has_24hr_electricity", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("is_gated_estate", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("has_security_guard", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("has_cctv", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("instant_book", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("is_published", sa.Boolean, nullable=False, server_default=sa.true()),
    )
    op.create_index("ix_listings_host_id", "listings", ["host_id"])
    op.create_index("ix_listings_city", "listings", ["city"])

    op.create_table(
        "listing_photos",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("listings.id"), nullable=False),
        sa.Column("url", sa.String(500), nullable=False),
        sa.Column("position", sa.Integer, nullable=False, server_default="0"),
    )
    op.create_index("ix_listing_photos_listing_id", "listing_photos", ["listing_id"])

    op.create_table(
        "availability_blocks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("listings.id"), nullable=False),
        sa.Column("start_date", sa.Date, nullable=False),
        sa.Column("end_date", sa.Date, nullable=False),
        sa.Column("is_blocked", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.Column("override_nightly_rate", sa.Numeric(12, 2), nullable=True),
    )
    op.create_index("ix_availability_blocks_listing_id", "availability_blocks", ["listing_id"])

    op.create_table(
        "bookings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("listings.id"), nullable=False),
        sa.Column("guest_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("host_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("check_in", sa.Date, nullable=False),
        sa.Column("check_out", sa.Date, nullable=False),
        sa.Column("num_guests", sa.Integer, nullable=False, server_default="1"),
        sa.Column("nights", sa.Integer, nullable=False),
        sa.Column("subtotal", sa.Numeric(12, 2), nullable=False),
        sa.Column("discount_amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("cleaning_fee", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("platform_fee", sa.Numeric(12, 2), nullable=False),
        sa.Column("host_payout_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("total_price", sa.Numeric(12, 2), nullable=False),
        sa.Column("status", booking_status, nullable=False, server_default="pending_host_approval"),
        sa.Column("payout_release_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paystack_reference", sa.String(100), nullable=True),
        sa.UniqueConstraint("paystack_reference"),
    )
    op.create_index("ix_bookings_listing_id", "bookings", ["listing_id"])
    op.create_index("ix_bookings_guest_id", "bookings", ["guest_id"])
    op.create_index("ix_bookings_host_id", "bookings", ["host_id"])

    op.create_table(
        "payments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("booking_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("bookings.id"), nullable=False),
        sa.Column("reference", sa.String(100), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False, server_default="NGN"),
        sa.Column("status", payment_status, nullable=False, server_default="initialized"),
        sa.Column("paystack_authorization_url", sa.String(500), nullable=True),
        sa.Column("paystack_raw_response", sa.String, nullable=True),
        sa.UniqueConstraint("reference"),
    )
    op.create_index("ix_payments_booking_id", "payments", ["booking_id"])
    op.create_index("ix_payments_reference", "payments", ["reference"])

    op.create_table(
        "conversations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("listings.id"), nullable=False),
        sa.Column("guest_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("host_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
    )
    op.create_index("ix_conversations_listing_id", "conversations", ["listing_id"])
    op.create_index("ix_conversations_guest_id", "conversations", ["guest_id"])
    op.create_index("ix_conversations_host_id", "conversations", ["host_id"])

    op.create_table(
        "messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("conversation_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("conversations.id"), nullable=False),
        sa.Column("sender_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("body", sa.Text, nullable=False),
        sa.Column("image_url", sa.String(500), nullable=True),
    )
    op.create_index("ix_messages_conversation_id", "messages", ["conversation_id"])
    op.create_index("ix_messages_sender_id", "messages", ["sender_id"])

    op.create_table(
        "reviews",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("booking_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("bookings.id"), nullable=False),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("listings.id"), nullable=False),
        sa.Column("guest_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("cleanliness", sa.Integer, nullable=False),
        sa.Column("communication", sa.Integer, nullable=False),
        sa.Column("accuracy", sa.Integer, nullable=False),
        sa.Column("location_rating", sa.Integer, nullable=False),
        sa.Column("value", sa.Integer, nullable=False),
        sa.Column("comment", sa.Text, nullable=True),
        sa.UniqueConstraint("booking_id"),
    )
    op.create_index("ix_reviews_listing_id", "reviews", ["listing_id"])
    op.create_index("ix_reviews_guest_id", "reviews", ["guest_id"])


def downgrade() -> None:
    op.drop_table("reviews")
    op.drop_table("messages")
    op.drop_table("conversations")
    op.drop_table("payments")
    op.drop_table("bookings")
    op.drop_table("availability_blocks")
    op.drop_table("listing_photos")
    op.drop_table("listings")
    op.drop_table("users")
    postgresql.ENUM(name="payment_status").drop(op.get_bind(), checkfirst=True)
    postgresql.ENUM(name="booking_status").drop(op.get_bind(), checkfirst=True)
