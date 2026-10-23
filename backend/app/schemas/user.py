import uuid
from datetime import datetime
from typing import Literal

from pydantic import Field, BaseModel, ConfigDict, EmailStr


class UserRegister(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    phone_number: str | None = None
    #: Ignored by the server - see SocialLoginRequest.is_host.
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
    #: Ignored by the server: host accounts are only ever created or enabled
    #: by the iStay team (see POST /admin/hosts). Kept so older clients that
    #: still send it don't fail validation.
    is_host: bool = False


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    full_name: str
    email: EmailStr
    phone_number: str | None
    is_host: bool
    is_admin: bool
    must_change_password: bool = False
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


class HostCreate(BaseModel):
    """Admin request to onboard a vetted host: promotes an existing account by
    email, or creates one when a password is supplied."""

    email: EmailStr
    full_name: str | None = None
    phone_number: str | None = None
    password: str | None = None


class ChangePasswordRequest(BaseModel):
    #: Omitted/ignored for accounts that signed up with Google/Apple/Facebook and
    #: never had a password - they can set one without proving a current one.
    current_password: str | None = None
    new_password: str = Field(min_length=8, max_length=128)


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str
    dev_reset_code: str | None = None


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str = Field(min_length=8, max_length=128)
