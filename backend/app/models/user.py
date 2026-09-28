from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class User(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "users"

    full_name: Mapped[str] = mapped_column(String(150))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    # Nullable: an account created via Google/Apple/Facebook never sets one.
    # Login therefore has two paths - see api/v1/auth.py's login() rejects
    # with a clear error rather than crashing on None if a social-only account
    # ever tries the password form.
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # Which route created this account - 'password' or a provider name.
    # Purely informational (e.g. for support and analytics): login itself
    # never branches on it, since it works equally by email for any provider,
    # including a user who originally signed up with a password.
    auth_provider: Mapped[str] = mapped_column(String(20), default="password", server_default="password")
    phone_number: Mapped[str | None] = mapped_column(String(20), unique=True, index=True, nullable=True)

    is_host: Mapped[bool] = mapped_column(Boolean, default=False)
    # Staff who can approve/reject verification documents - see api/v1/admin.py.
    # Set by hand in the database; there is no signup path that grants this.
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)

    # KYC: no ID verification vendor is wired up yet, so this is a manual/self-declared
    # status set to "pending" on document upload and flipped via an authenticated PATCH
    # until a vendor like Smile Identity is integrated.
    verification_status: Mapped[str] = mapped_column(String(20), default="unverified")
    id_document_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    selfie_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    payout_bank_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    payout_account_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    payout_account_name: Mapped[str | None] = mapped_column(String(150), nullable=True)

    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    otp_code_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    otp_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    listings = relationship("Listing", back_populates="host", cascade="all, delete-orphan")
