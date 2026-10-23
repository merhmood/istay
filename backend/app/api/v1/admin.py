import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_admin
from app.db.session import get_db
from app.models.user import User
from app.core.security import hash_password
from app.schemas.user import HostCreate, UserOut, VerificationRequestOut, VerificationStatusUpdate

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/verifications", response_model=list[VerificationRequestOut])
async def list_verification_requests(
    status_filter: str = Query(default="pending", alias="status"),
    _admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> list[User]:
    """Everyone at a given verification status, newest submission first.

    Defaults to "pending" - the reviewer's queue - but accepts "verified" or
    "rejected" too, so a decision can be double-checked or reversed without a
    database console.
    """
    if status_filter not in {"unverified", "pending", "verified", "rejected"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid status")

    result = await db.execute(
        select(User).where(User.verification_status == status_filter).order_by(User.created_at.desc())
    )
    return list(result.scalars().all())


@router.patch("/verifications/{user_id}", response_model=VerificationRequestOut)
async def review_verification_request(
    user_id: uuid.UUID,
    payload: VerificationStatusUpdate,
    _admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.verification_status = payload.status
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/hosts", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_host(
    payload: HostCreate,
    _admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Onboard a vetted host. Host signup is closed to the public, so this is
    the only way an account becomes a host: it promotes an existing account
    with that email, or creates a new one when a password is supplied."""
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    if user:
        user.is_host = True
        # The admin vetted this person by hand, so no ID/selfie step.
        user.verification_status = "verified"
    else:
        if not payload.password or not payload.full_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No account with that email - supply full_name and password to create one",
            )
        user = User(
            full_name=payload.full_name,
            email=payload.email,
            hashed_password=hash_password(payload.password),
            phone_number=payload.phone_number,
            is_host=True,
            verification_status="verified",
            # The admin hands over this password, so the host must replace it.
            must_change_password=True,
        )
        db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.get("/hosts", response_model=list[UserOut])
async def list_hosts(
    _admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> list[User]:
    """Every host account, newest first."""
    result = await db.execute(select(User).where(User.is_host.is_(True)).order_by(User.created_at.desc()))
    return list(result.scalars().all())
