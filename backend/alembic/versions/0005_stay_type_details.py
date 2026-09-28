"""minimum stay and breakfast-included on listings

The stay-type taxonomy (0004 was interactions; this taxonomy itself needed no
migration since property_type was already a free string) implies real
constraints that were missing: a Long stay listing billed monthly has no floor
on how short a booking can be, and "often including breakfast" - the actual
wording of three of the ten stay-type descriptions - was never a field a host
could set or a guest could see.

Revision ID: 0005_stay_type_details
Revises: 0004_listing_interactions
Create Date: 2026-09-24
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005_stay_type_details"
down_revision: Union[str, None] = "0004_listing_interactions"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "listings",
        sa.Column("minimum_nights", sa.Integer(), nullable=False, server_default="1"),
    )
    op.add_column(
        "listings",
        sa.Column("breakfast_included", sa.Boolean(), nullable=False, server_default="false"),
    )


def downgrade() -> None:
    op.drop_column("listings", "breakfast_included")
    op.drop_column("listings", "minimum_nights")
