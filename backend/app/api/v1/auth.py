from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
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
from app.core.observability import AUTH_LIMIT, OTP_LIMIT, limiter
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    ResetPasswordRequest,
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
from app.services.email import send_email
from app.services.otp import generate_otp_code, hash_otp, otp_expiry, send_sms, verify_otp_code
from app.services.social_auth import SocialAuthError, verify
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
@limiter.limit(AUTH_LIMIT)
async def register(request: Request, payload: UserRegister, db: AsyncSession = Depends(get_db)) -> TokenPair:
    if payload.is_host:
        # Hosts are vetted and onboarded manually by the iStay team.
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Host accounts are created by the iStay team. Please contact support to become a host.",
        )
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        full_name=payload.full_name,
        email=payload.email,
        hashed_password=hash_password(payload.password),
        phone_number=payload.phone_number,
        is_host=False,
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
@limiter.limit(AUTH_LIMIT)
async def login(request: Request, payload: UserLogin, db: AsyncSession = Depends(get_db)) -> TokenPair:
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
@limiter.limit(AUTH_LIMIT)
async def social_login(request: Request, payload: SocialLoginRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
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
            is_host=False,
            email_verified=identity.email_verified,
            auth_provider=payload.provider,
        )
        db.add(user)

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
@limiter.limit(OTP_LIMIT)
async def request_otp(request: Request, payload: RequestOtp, db: AsyncSession = Depends(get_db)) -> OtpResponse:
    result = await db.execute(select(User).where(User.phone_number == payload.phone_number))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No account with that phone number")

    code = generate_otp_code()
    user.otp_code_hash = hash_otp(code)
    user.otp_expires_at = otp_expiry()
    await db.commit()

    await send_sms(payload.phone_number, f"Your iStay verification code is {code}")

    return OtpResponse(
        message="OTP sent",
        dev_otp_code=code if settings.is_dev else None,
    )


@router.post("/verify-otp", response_model=UserOut)
@limiter.limit(OTP_LIMIT)
async def verify_otp(request: Request, payload: VerifyOtp, db: AsyncSession = Depends(get_db)) -> UserOut:
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


RESET_CODE_TTL_MINUTES = 15
RESET_MAX_ATTEMPTS = 5


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(AUTH_LIMIT)
async def change_password(
    request: Request,
    payload: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    if current_user.hashed_password:
        if not payload.current_password or not verify_password(payload.current_password, current_user.hashed_password):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Current password is incorrect")
    current_user.hashed_password = hash_password(payload.new_password)
    current_user.must_change_password = False
    await db.commit()


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
@limiter.limit(OTP_LIMIT)
async def forgot_password(
    request: Request, payload: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)
) -> ForgotPasswordResponse:
    """Emails a one-time reset code. Answers identically whether or not the
    account exists, so it can't be used to discover who has an account."""
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    dev_code = None
    if user:
        code = generate_otp_code()
        user.reset_code_hash = hash_otp(code)
        user.reset_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=RESET_CODE_TTL_MINUTES)
        user.reset_attempts = 0
        await db.commit()
        await send_email(
            user.email,
            "Your iStay password reset code",
            f"Your iStay password reset code is {code}. It expires in {RESET_CODE_TTL_MINUTES} minutes. "
            "If you didn't ask for this, you can ignore this email.",
        )
        if user.phone_number:
            try:
                await send_sms(user.phone_number, f"Your iStay password reset code is {code}")
            except NotImplementedError:
                pass  # no SMS provider yet - the email above is the only channel
        if settings.is_dev:
            dev_code = code

    return ForgotPasswordResponse(
        message="If an account exists for that email, a reset code has been sent.",
        dev_reset_code=dev_code,
    )


@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(OTP_LIMIT)
async def reset_password(request: Request, payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)) -> None:
    invalid = HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    if not user or not user.reset_code_hash or not user.reset_code_expires_at:
        raise invalid
    if user.reset_code_expires_at < datetime.now(timezone.utc) or user.reset_attempts >= RESET_MAX_ATTEMPTS:
        raise invalid

    if not verify_otp_code(payload.code, user.reset_code_hash):
        user.reset_attempts += 1
        await db.commit()
        raise invalid

    user.hashed_password = hash_password(payload.new_password)
    user.must_change_password = False
    user.reset_code_hash = None
    user.reset_code_expires_at = None
    user.reset_attempts = 0
    await db.commit()
