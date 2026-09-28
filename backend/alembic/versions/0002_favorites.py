"""add favorites table

Revision ID: 0002_favorites
Revises: 0001_initial
Create Date: 2026-09-21
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002_favorites"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "favorites",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("listings.id"), nullable=False),
        sa.UniqueConstraint("user_id", "listing_id", name="uq_favorites_user_listing"),
    )
    op.create_index("ix_favorites_user_id", "favorites", ["user_id"])
    op.create_index("ix_favorites_listing_id", "favorites", ["listing_id"])


def downgrade() -> None:
    op.drop_table("favorites")
