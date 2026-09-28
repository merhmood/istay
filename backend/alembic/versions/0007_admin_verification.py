"""admin flag for verification approval

There is no admin dashboard, just a flag on the same `users` table and a
handful of gated endpoints - a Nigerian marketplace this size doesn't need a
separate staff app yet, and the host app already has an authenticated shell
to hang an admin-only screen off of.

Revision ID: 0007_admin_verification
Revises: 0006_social_login
Create Date: 2026-09-26
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0007_admin_verification"
down_revision: Union[str, None] = "0006_social_login"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("is_admin", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    op.drop_column("users", "is_admin")
