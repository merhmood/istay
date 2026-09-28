"""Thin client around Paystack's Transactions API.

Uses the secret test key from settings. Swap PAYSTACK_SECRET_KEY / PAYSTACK_PUBLIC_KEY
in .env for live keys when ready to go to production - no code changes needed.
"""

import httpx

from app.core.config import settings

PAYSTACK_BASE_URL = "https://api.paystack.co"


class PaystackError(Exception):
    pass


async def initialize_transaction(email: str, amount_naira: float, reference: str) -> dict:
    amount_kobo = int(round(amount_naira * 100))
    async with httpx.AsyncClient(base_url=PAYSTACK_BASE_URL, timeout=15) as client:
        response = await client.post(
            "/transaction/initialize",
            headers={"Authorization": f"Bearer {settings.paystack_secret_key}"},
            json={
                "email": email,
                "amount": amount_kobo,
                "reference": reference,
                "currency": "NGN",
            },
        )
    data = response.json()
    if not data.get("status"):
        raise PaystackError(data.get("message", "Failed to initialize Paystack transaction"))
    return data["data"]


async def verify_transaction(reference: str) -> dict:
    async with httpx.AsyncClient(base_url=PAYSTACK_BASE_URL, timeout=15) as client:
        response = await client.get(
            f"/transaction/verify/{reference}",
            headers={"Authorization": f"Bearer {settings.paystack_secret_key}"},
        )
    data = response.json()
    if not data.get("status"):
        raise PaystackError(data.get("message", "Failed to verify Paystack transaction"))
    return data["data"]
