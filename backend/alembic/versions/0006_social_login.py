"""social sign-in: nullable password, auth provider

A Google/Apple/Facebook account has no password to hash, so the column that
used to be required can no longer be. `auth_provider` is purely informational
- login resolves by email regardless of how the account was created.

Revision ID: 0006_social_login
Revises: 0005_stay_type_details
Create Date: 2026-09-24
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0006_social_login"
down_revision: Union[str, None] = "0005_stay_type_details"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=True)
    op.add_column(
        "users",
        sa.Column("auth_provider", sa.String(20), nullable=False, server_default="password"),
    )


def downgrade() -> None:
    op.drop_column("users", "auth_provider")
    # Not reversible in general - a social-only account has no password to
    # restore. Fine for a downgrade path in development; existing NULLs would
    # need real passwords set before this could run against production data.
    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=False)
