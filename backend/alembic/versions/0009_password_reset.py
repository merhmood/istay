"""password reset codes

Revision ID: 0009_password_reset
Revises: 0008_flutterwave
Create Date: 2026-10-24
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0009_password_reset"
down_revision: Union[str, None] = "0008_flutterwave"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("reset_code_hash", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("reset_code_expires_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("reset_attempts", sa.Integer(), nullable=False, server_default="0"))


def downgrade() -> None:
    op.drop_column("users", "reset_attempts")
    op.drop_column("users", "reset_code_expires_at")
    op.drop_column("users", "reset_code_hash")
