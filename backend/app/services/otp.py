"""OTP generation/verification.

No SMS provider (e.g. Termii, Twilio) is wired up yet. `send_sms` is the single seam to
swap in a real provider later - everything else (hashing, expiry, verification) is real.
"""

import random
from datetime import datetime, timedelta, timezone

from app.core.config import settings
from app.core.security import hash_password, verify_password

OTP_TTL_MINUTES = 10


def generate_otp_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def hash_otp(code: str) -> str:
    return hash_password(code)


def verify_otp_code(code: str, code_hash: str) -> bool:
    return verify_password(code, code_hash)


def otp_expiry() -> datetime:
    return datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)


async def send_sms(phone_number: str, message: str) -> None:
    """Placeholder for a real SMS provider integration (e.g. Termii, Africa's Talking, Twilio).

    In dev, the OTP is returned directly in the API response instead of being sent, so
    the flow is testable without a paid SMS account.
    """
    if settings.is_dev:
        print(f"[dev] SMS to {phone_number}: {message}")
    else:
        raise NotImplementedError("No SMS provider configured. Wire one up here for production use.")
