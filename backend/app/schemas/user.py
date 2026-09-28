import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr


class UserRegister(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    phone_number: str | None = None
    is_host: bool = False


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class SocialLoginRequest(BaseModel):
    provider: Literal["google", "facebook", "apple"]
    #: The provider's own signed token - a Google/Facebook access or id token,
    #: or an Apple identity token. Never a client-asserted email; see
    #: services/social_auth.py for why.
    token: str
    #: Apple only sends the user's name on the very first authorisation, so
    #: the client captures it then and passes it through here; every other
    #: provider's name comes back inside the verified token/profile itself.
    full_name: str | None = None
    #: Which app this sign-in came from - the host app passes True so a new
    #: account starts host-enabled, matching how /register already works.
    is_host: bool = False


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    full_name: str
    email: EmailStr
    phone_number: str | None
    is_host: bool
    is_admin: bool
    phone_verified: bool
    email_verified: bool
    verification_status: str
    avatar_url: str | None
    # Returned so the host app can show what's currently on file. Without these
    # the payout form was write-only: a host could save details and had no way
    # to confirm they had stuck.
    payout_bank_name: str | None = None
    payout_account_number: str | None = None
    payout_account_name: str | None = None


class UserUpdate(BaseModel):
    full_name: str | None = None
    phone_number: str | None = None
    avatar_url: str | None = None
    is_host: bool | None = None
    payout_bank_name: str | None = None
    payout_account_number: str | None = None
    payout_account_name: str | None = None


class VerificationRequestOut(BaseModel):
    """A user's KYC submission, as shown on the admin approval screen.

    Deliberately not part of `UserOut` - the document/selfie URLs have no
    reason to ever reach a guest or host's own client, only the reviewer's.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    full_name: str
    email: EmailStr
    phone_number: str | None
    is_host: bool
    verification_status: str
    id_document_url: str | None
    selfie_url: str | None
    created_at: datetime


class VerificationStatusUpdate(BaseModel):
    status: Literal["verified", "rejected"]


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str


class RequestOtp(BaseModel):
    phone_number: str


class VerifyOtp(BaseModel):
    phone_number: str
    code: str


class OtpResponse(BaseModel):
    message: str
    dev_otp_code: str | None = None
