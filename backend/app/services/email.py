"""Outbound email.

No email provider (Resend, SendGrid, Mailgun...) is wired up yet. `send_email`
is the single seam to swap one in - the reset-code flow around it is real.
"""

import logging

from app.core.config import settings

logger = logging.getLogger("staynaija.email")


async def send_email(to: str, subject: str, body: str) -> None:
    if settings.is_dev:
        print(f"[dev] Email to {to}: {subject}\n{body}")
        return
    # Not raising: forgot-password deliberately answers the same way whether or
    # not the account exists, so a failure here must not change the response.
    logger.error("No email provider configured; dropped email to %s (%s)", to, subject)
