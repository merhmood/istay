from collections.abc import AsyncGenerator
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


def prepare_database_url(raw_url: str) -> tuple[str, dict]:
    """Normalise a possibly-copy-pasted connection string into one this
    project's async setup can actually use.

    Two independent gotchas, both real ones a managed Postgres provider's
    dashboard will hand you verbatim if you paste the string as given:

    * No driver named in the scheme (`postgresql://...`, or Heroku/Neon's
      older `postgres://...`) - SQLAlchemy then defaults to the sync
      `psycopg2` dialect, which isn't installed (this project only installs
      `asyncpg`), and fails with `ModuleNotFoundError: No module named
      'psycopg2'` - a confusing error for what's really just a missing
      `+asyncpg` in the scheme. Upgraded automatically here rather than left
      as a step someone can forget mid copy-paste.
    * `sslmode=require&channel_binding=require` - libpq-style query params
      meant for psycopg, not asyncpg. asyncpg only recognises an `ssl`
      *keyword argument*; left in the URL's query string, these get
      forwarded as unrecognised connect kwargs and asyncpg rejects the
      connection outright.

    Local dev's plain compose URL already has neither issue, so both of
    these are no-ops there.
    """
    parts = urlsplit(raw_url)

    scheme = parts.scheme
    if scheme in ("postgresql", "postgres"):
        scheme = "postgresql+asyncpg"
    parts = parts._replace(scheme=scheme)

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
