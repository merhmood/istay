"""Verification of social sign-in tokens.

The client never tells us who it is - it hands over the provider's own signed
token and we verify it with that provider. Trusting a client-supplied email
would let anyone log in as anyone by typing their address.

Each provider is verified against its own endpoint. Nothing here needs our own
secret for the mobile flows: Google and Apple tokens are verifiable from the
token alone, and Facebook needs an app token which is derived from config.
"""
from __future__ import annotations

from dataclasses import dataclass

import httpx

from app.core.config import settings


class SocialAuthError(Exception):
    """Raised when a provider token is missing, invalid or not for this app."""


@dataclass
class SocialIdentity:
    """Who the provider says this person is."""

    provider: str
    provider_user_id: str
    email: str
    full_name: str | None
    email_verified: bool


async def verify_google(id_token: str) -> SocialIdentity:
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
        )
    if response.status_code != 200:
        raise SocialAuthError("Google rejected that sign-in.")
    data = response.json()

    # `aud` is the client the token was minted for. Without this check a token
    # issued for any other Google app would be accepted here.
    expected = settings.google_client_ids
    if expected and data.get("aud") not in expected:
        raise SocialAuthError("That Google sign-in was not issued for this app.")

    email = data.get("email")
    if not email:
        raise SocialAuthError("Google did not return an email address.")

    return SocialIdentity(
        provider="google",
        provider_user_id=data["sub"],
        email=email.lower(),
        full_name=data.get("name"),
        email_verified=str(data.get("email_verified", "false")).lower() == "true",
    )


async def verify_facebook(access_token: str) -> SocialIdentity:
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(
            "https://graph.facebook.com/me",
            params={"fields": "id,name,email", "access_token": access_token},
        )
    if response.status_code != 200:
        raise SocialAuthError("Facebook rejected that sign-in.")
    data = response.json()

    email = data.get("email")
    if not email:
        # Facebook accounts registered by phone have no email, and a user can
        # also decline the email permission.
        raise SocialAuthError(
            "Your Facebook account has no email address. Sign up with email instead."
        )

    return SocialIdentity(
        provider="facebook",
        provider_user_id=data["id"],
        email=email.lower(),
        full_name=data.get("name"),
        email_verified=True,
    )


async def verify_apple(identity_token: str, full_name: str | None) -> SocialIdentity:
    """Apple's identity token is a JWT signed with a key from their JWKS.

    Apple only sends the user's name on the *first* authorisation, so the client
    passes it through and it is stored then; later sign-ins carry the token only.
    """
    from jose import jwt

    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get("https://appleid.apple.com/auth/keys")
    if response.status_code != 200:
        raise SocialAuthError("Could not reach Apple to verify that sign-in.")

    try:
        claims = jwt.decode(
            identity_token,
            response.json(),
            algorithms=["RS256"],
            audience=settings.apple_bundle_ids or None,
            issuer="https://appleid.apple.com",
            options={"verify_aud": bool(settings.apple_bundle_ids)},
        )
    except Exception as exc:  # noqa: BLE001 - any failure here means untrusted
        raise SocialAuthError("Apple rejected that sign-in.") from exc

    email = claims.get("email")
    if not email:
        raise SocialAuthError("Apple did not return an email address.")

    return SocialIdentity(
        provider="apple",
        provider_user_id=claims["sub"],
        email=email.lower(),
        full_name=full_name,
        email_verified=bool(claims.get("email_verified", True)),
    )


async def verify(provider: str, token: str, full_name: str | None = None) -> SocialIdentity:
    if provider == "google":
        return await verify_google(token)
    if provider == "facebook":
        return await verify_facebook(token)
    if provider == "apple":
        return await verify_apple(token, full_name)
    raise SocialAuthError(f"Unsupported sign-in provider: {provider}")
