from collections.abc import AsyncGenerator
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


def prepare_database_url(raw_url: str) -> tuple[str, dict]:
    """Strip query params asyncpg doesn't understand, translating them to the
    connect_args it does.

    A managed Postgres connection string (Neon's, for one) comes with
    `sslmode=require&channel_binding=require` - libpq-style params meant for
    psycopg, not asyncpg. asyncpg only recognises an `ssl` *keyword argument*;
    left in the URL's query string, these get forwarded as unrecognised
    connect kwargs and asyncpg rejects the connection outright. Local dev's
    plain compose URL carries no such params, so this is a no-op there.
    """
    parts = urlsplit(raw_url)
    query = dict(parse_qsl(parts.query))
    wants_ssl = query.pop("sslmode", None) not in (None, "disable")
    query.pop("channel_binding", None)
    cleaned = urlunsplit(parts._replace(query=urlencode(query)))
    return cleaned, ({"ssl": True} if wants_ssl else {})


_database_url, _connect_args = prepare_database_url(settings.database_url)
engine = create_async_engine(_database_url, echo=False, future=True, connect_args=_connect_args)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session
