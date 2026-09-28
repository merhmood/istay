"""browsing signals for the recommendation model

Bookings and favourites are too sparse to drive recommendations on their own -
a guest books a handful of times a year but views dozens of listings a week.
This table captures the lighter signals (detail views, map marker taps and
directions requests) that make both halves of the hybrid model work, and is the
first source dense enough for collaborative filtering to ever activate.

Revision ID: 0004_listing_interactions
Revises: 0003_search_indexes
Create Date: 2026-09-23
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0004_listing_interactions"
down_revision: Union[str, None] = "0003_search_indexes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "listing_interactions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        # Nullable: browsing without an account is supported, and throwing those
        # events away would discard most of the data this table exists to collect.
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("anonymous_id", sa.String(64), nullable=True),
        sa.Column(
            "listing_id",
            UUID(as_uuid=True),
            sa.ForeignKey("listings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("kind", sa.String(24), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_listing_interactions_user_id", "listing_interactions", ["user_id"])
    op.create_index("ix_listing_interactions_anonymous_id", "listing_interactions", ["anonymous_id"])
    op.create_index("ix_listing_interactions_listing_id", "listing_interactions", ["listing_id"])
    op.create_index("ix_listing_interactions_occurred_at", "listing_interactions", ["occurred_at"])
    # Building one guest's taste profile reads their whole history in date order.
    op.create_index(
        "ix_listing_interactions_user_created", "listing_interactions", ["user_id", "created_at"]
    )
    # Counting engagement per listing, which is how trending is computed.
    op.create_index(
        "ix_listing_interactions_listing_kind", "listing_interactions", ["listing_id", "kind"]
    )


def downgrade() -> None:
    op.drop_table("listing_interactions")
