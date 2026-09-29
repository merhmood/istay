from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserOut, UserUpdate
from app.services.storage import save_upload

router = APIRouter(prefix="/users", tags=["users"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.get("/me", response_model=UserOut)
async def get_my_profile(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)


@router.patch("/me", response_model=UserOut)
async def update_my_profile(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(current_user, field, value)
    await db.commit()
    await db.refresh(current_user)
    return UserOut.model_validate(current_user)


@router.post("/me/verification-documents", response_model=UserOut)
async def upload_verification_documents(
    id_document: UploadFile = File(...),
    selfie: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    if id_document.content_type not in ALLOWED_IMAGE_TYPES or selfie.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only JPEG/PNG/WEBP images are accepted")

    current_user.id_document_url = await save_upload(id_document, "id-documents")
    current_user.selfie_url = await save_upload(selfie, "selfies")
    # No KYC vendor integrated yet - documents land in "pending" for manual review
    # via the admin-only endpoints in api/v1/admin.py until one is wired up.
    current_user.verification_status = "pending"
    await db.commit()
    await db.refresh(current_user)
    return UserOut.model_validate(current_user)

