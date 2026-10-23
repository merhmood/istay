"""Rate limiting is disabled globally in conftest; flip it on for one test."""

from app.core.observability import limiter
from app.db.session import get_db
from app.main import app


class _NoUserSession:
    async def execute(self, *_args, **_kwargs):
        class _Result:
            def scalar_one_or_none(self):
                return None

        return _Result()


async def _no_user_db():
    yield _NoUserSession()


async def test_login_is_rate_limited(anon_client):
    app.dependency_overrides[get_db] = _no_user_db
    limiter.enabled = True
    limiter.reset()
    try:
        body = {"email": "nobody@example.com", "password": "whatever1"}
        codes = [(await anon_client.post("/api/v1/auth/login", json=body)).status_code for _ in range(12)]
        assert codes[0] == 401
        assert codes[-1] == 429
        assert codes.count(401) == 10  # AUTH_LIMIT is 10/minute
    finally:
        limiter.enabled = False
        limiter.reset()
        app.dependency_overrides.clear()
