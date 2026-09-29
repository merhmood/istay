"""Where an uploaded file (listing photo, ID document, selfie) actually ends
up.

Bunny Storage with a CDN pull zone in front when configured - production's
setup, since Magic Containers' local container disk doesn't survive a
redeploy and isn't shared if the app is ever scaled past one instance (see
docs/deploy-backend.md). Falls back to local disk under `upload_dir`
otherwise, so running the app locally never requires a Bunny account.
"""
from __future__ import annotations

import os
import uuid

import httpx
from fastapi import UploadFile

from app.core.config import settings


def _unique_filename(original: str | None) -> str:
    ext = os.path.splitext(original or "")[1] or ".jpg"
    return f"{uuid.uuid4()}{ext}"


async def save_upload(file: UploadFile, subdir: str) -> str:
    """Stores `file` under `subdir` and returns a URL it can be fetched back
    from - the caller doesn't need to know which backend served it.
    """
    filename = _unique_filename(file.filename)
    content = await file.read()

    if settings.bunny_storage_configured:
        return await _save_to_bunny(content, subdir, filename)
    return _save_to_local_disk(content, subdir, filename)


async def _save_to_bunny(content: bytes, subdir: str, filename: str) -> str:
    region_prefix = f"{settings.bunny_storage_region}." if settings.bunny_storage_region else ""
    upload_url = f"https://{region_prefix}storage.bunnycdn.com/{settings.bunny_storage_zone}/{subdir}/{filename}"
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.put(
            upload_url,
            content=content,
            headers={
                "AccessKey": settings.bunny_storage_access_key,
                "Content-Type": "application/octet-stream",
            },
        )
        response.raise_for_status()
    # Fetched back through the pull zone, never the storage endpoint itself -
    # that endpoint authenticates writes, it isn't meant to serve traffic.
    return f"https://{settings.bunny_storage_pull_zone_host}/{subdir}/{filename}"


def _save_to_local_disk(content: bytes, subdir: str, filename: str) -> str:
    directory = os.path.join(settings.upload_dir, subdir)
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, filename), "wb") as f:
        f.write(content)
    # A host-less path like "/uploads/..." has no origin for an image loader
    # (CachedNetworkImage, etc.) to resolve against - it needs a real URL.
    return f"{settings.public_base_url}/{settings.upload_dir}/{subdir}/{filename}"
