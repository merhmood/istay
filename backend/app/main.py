import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1 import admin, auth, availability, bookings, favorites, listings, messages, payments, reviews, users, ws
from app.core.config import settings

app = FastAPI(title="StayNaija API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs(settings.upload_dir, exist_ok=True)
app.mount(f"/{settings.upload_dir}", StaticFiles(directory=settings.upload_dir), name="uploads")

API_PREFIX = "/api/v1"
app.include_router(auth.router, prefix=API_PREFIX)
app.include_router(users.router, prefix=API_PREFIX)
app.include_router(listings.router, prefix=API_PREFIX)
app.include_router(availability.router, prefix=API_PREFIX)
app.include_router(bookings.router, prefix=API_PREFIX)
app.include_router(payments.router, prefix=API_PREFIX)
app.include_router(messages.router, prefix=API_PREFIX)
app.include_router(reviews.router, prefix=API_PREFIX)
app.include_router(favorites.router, prefix=API_PREFIX)
app.include_router(admin.router, prefix=API_PREFIX)
app.include_router(ws.router, prefix=API_PREFIX)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
