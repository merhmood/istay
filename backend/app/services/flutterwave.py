"""Thin client around Flutterwave's Transactions (v3) API.

Uses the secret test key from settings. Swap FLUTTERWAVE_SECRET_KEY /
FLUTTERWAVE_PUBLIC_KEY in .env for live keys when ready to go to production -
no code changes needed.
"""

import httpx

from app.core.config import settings

FLUTTERWAVE_BASE_URL = "https://api.flutterwave.com/v3"


class FlutterwaveError(Exception):
    pass


async def initialize_transaction(email: str, amount_naira: float, reference: str, redirect_url: str) -> dict:
    async with httpx.AsyncClient(base_url=FLUTTERWAVE_BASE_URL, timeout=15) as client:
        response = await client.post(
            "/payments",
            headers={"Authorization": f"Bearer {settings.flutterwave_secret_key}"},
            json={
                "tx_ref": reference,
                "amount": amount_naira,
                "currency": "NGN",
                "redirect_url": redirect_url,
                "customer": {"email": email},
            },
        )
    data = response.json()
    if data.get("status") != "success":
        raise FlutterwaveError(data.get("message", "Failed to initialize Flutterwave transaction"))
    return data["data"]


async def verify_transaction(reference: str) -> dict:
    async with httpx.AsyncClient(base_url=FLUTTERWAVE_BASE_URL, timeout=15) as client:
        response = await client.get(
            "/transactions/verify_by_reference",
            params={"tx_ref": reference},
            headers={"Authorization": f"Bearer {settings.flutterwave_secret_key}"},
        )
    data = response.json()
    if data.get("status") != "success":
        raise FlutterwaveError(data.get("message", "Failed to verify Flutterwave transaction"))
    return data["data"]
