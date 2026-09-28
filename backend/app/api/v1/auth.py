from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import (
    OtpResponse,
    RefreshRequest,
    RequestOtp,
    SocialLoginRequest,
    TokenPair,
    UserLogin,
    UserOut,
    UserRegister,
    VerifyOtp,
)
from app.services.otp import generate_otp_code, hash_otp, otp_expiry, send_sms, verify_otp_code
from app.services.social_auth import SocialAuthError, verify
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
async def register(payload: UserRegister, db: AsyncSession = Depends(get_db)) -> TokenPair:
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        full_name=payload.full_name,
        email=payload.email,
        hashed_password=hash_password(payload.password),
        phone_number=payload.phone_number,
        is_host=payload.is_host,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return TokenPair(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserOut.model_validate(user),
    )


@router.post("/login", response_model=TokenPair)
async def login(payload: UserLogin, db: AsyncSession = Depends(get_db)) -> TokenPair:
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    # An account created via Google/Apple/Facebook has no password hash to
    # check against - `pwd_context.verify` would raise on None rather than
    # just returning False, so that case is turned into the same generic
    # rejection as a wrong password, before it ever reaches verify_password.
    if not user or user.hashed_password is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    return TokenPair(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserOut.model_validate(user),
    )


@router.post("/social", response_model=TokenPair)
async def social_login(payload: SocialLoginRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
    """Sign in (or silently register) with a Google/Apple/Facebook token.

    The client never asserts who it is - it hands over the provider's own
    signed token, which `verify()` checks directly with that provider. The
    account is then resolved by email, the same identity key `/register` and
    `/login` already use, so someone who originally signed up with a password
    can sign in with Google later (or vice versa) without ending up with two
    separate accounts.
    """
    try:
        identity = await verify(payload.provider, payload.token, payload.full_name)
    except SocialAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    result = await db.execute(select(User).where(User.email == identity.email))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            full_name=identity.full_name or identity.email.split("@")[0],
            email=identity.email,
            hashed_password=None,
            is_host=payload.is_host,
            email_verified=identity.email_verified,
            auth_provider=payload.provider,
        )
        db.add(user)
    elif payload.is_host and not user.is_host:
        # Opening the host app with an identity already used as a guest -
        # extends the existing account to host rather than ever downgrading
        # in the other direction (host apps signing into the guest app must
        # not lose host status).
        user.is_host = True

    await db.commit()
    await db.refresh(user)

    return TokenPair(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserOut.model_validate(user),
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh(payload: RefreshRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
    user_id = decode_token(payload.refresh_token, "refresh")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return TokenPair(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserOut.model_validate(user),
    )


@router.post("/request-otp", response_model=OtpResponse)
async def request_otp(payload: RequestOtp, db: AsyncSession = Depends(get_db)) -> OtpResponse:
    result = await db.execute(select(User).where(User.phone_number == payload.phone_number))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No account with that phone number")

    code = generate_otp_code()
    user.otp_code_hash = hash_otp(code)
    user.otp_expires_at = otp_expiry()
    await db.commit()

    await send_sms(payload.phone_number, f"Your StayNaija verification code is {code}")

    return OtpResponse(
        message="OTP sent",
        dev_otp_code=code if settings.is_dev else None,
    )


@router.post("/verify-otp", response_model=UserOut)
async def verify_otp(payload: VerifyOtp, db: AsyncSession = Depends(get_db)) -> UserOut:
    result = await db.execute(select(User).where(User.phone_number == payload.phone_number))
    user = result.scalar_one_or_none()
    if not user or not user.otp_code_hash or not user.otp_expires_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No OTP requested for this number")

    if user.otp_expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP expired")

    if not verify_otp_code(payload.code, user.otp_code_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP")

    user.phone_verified = True
    user.otp_code_hash = None
    user.otp_expires_at = None
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)
