from fastapi import APIRouter

from app.core.config import settings

router = APIRouter(prefix="/config", tags=["config"])


@router.get("")
async def public_config() -> dict:
    """Server-decided flags the mobile apps read at startup, so behaviour like
    demo logins is controlled by the backend's environment, not baked into a
    build."""
    return {
        "show_demo_logins": settings.demo_logins_enabled,
        "support_whatsapp": settings.support_whatsapp or None,
        "support_email": settings.support_email or None,
    }
