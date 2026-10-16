"""rename Paystack-specific columns to provider-neutral names (Flutterwave migration)

Paystack has been fully replaced by Flutterwave as the payment provider.
These columns were named after the old provider; renaming them avoids leaving
a schema that's misleading about what's actually charging the guest.

Revision ID: 0008_flutterwave
Revises: 0007_admin_verification
Create Date: 2026-10-10
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0008_flutterwave"
down_revision: Union[str, None] = "0007_admin_verification"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("bookings", "paystack_reference", new_column_name="payment_reference")
    op.alter_column("payments", "paystack_authorization_url", new_column_name="checkout_url")
    op.alter_column("payments", "paystack_raw_response", new_column_name="provider_raw_response")


def downgrade() -> None:
    op.alter_column("bookings", "payment_reference", new_column_name="paystack_reference")
    op.alter_column("payments", "checkout_url", new_column_name="paystack_authorization_url")
    op.alter_column("payments", "provider_raw_response", new_column_name="paystack_raw_response")
