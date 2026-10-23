"""Test setup.

Pure-logic and signature tests run anywhere. Tests that touch the database use
the `client`/`db_session` fixtures, which need a real Postgres (the models use
Postgres-only types such as ARRAY/UUID) at TEST_DATABASE_URL, e.g.

    TEST_DATABASE_URL=postgresql+asyncpg://staynaija:staynaija@localhost:5433/staynaija_test

and are skipped when it is unset.
"""

import os

# Must be set before `app` is imported: settings are read at import time.
os.environ["RATE_LIMIT_ENABLED"] = "false"
os.environ["SENTRY_DSN"] = ""
os.environ["FLUTTERWAVE_WEBHOOK_SECRET_HASH"] = "test-hash"
os.environ["ENV"] = "dev"

import httpx
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app import models  # noqa: F401  (registers every table on Base.metadata)
from app.db.session import Base, get_db
from app.main import app

TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL")


@pytest_asyncio.fixture
async def db_session():
    if not TEST_DATABASE_URL:
        pytest.skip("TEST_DATABASE_URL not set")
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session):
    async def _override():
        yield db_session

    app.dependency_overrides[get_db] = _override
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def anon_client():
    """No database: for routes that reject the request before touching it."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as c:
        yield c
