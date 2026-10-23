import pytest

from app.db.session import get_db
from app.main import app


class _NoUserSession:
    async def execute(self, *_args, **_kwargs):
        class _Result:
            def scalar_one_or_none(self):
                return None

        return _Result()

    async def commit(self):
        pass


async def _no_user_db():
    yield _NoUserSession()


@pytest.fixture
def no_user_db():
    app.dependency_overrides[get_db] = _no_user_db
    yield
    app.dependency_overrides.clear()


async def test_forgot_password_does_not_reveal_unknown_accounts(anon_client, no_user_db):
    r = await anon_client.post("/api/v1/auth/forgot-password", json={"email": "nobody@example.com"})
    assert r.status_code == 200
    assert r.json()["dev_reset_code"] is None
    assert "If an account exists" in r.json()["message"]


async def test_reset_with_unknown_account_is_rejected(anon_client, no_user_db):
    r = await anon_client.post(
        "/api/v1/auth/reset-password",
        json={"email": "nobody@example.com", "code": "123456", "new_password": "newpassword1"},
    )
    assert r.status_code == 400


async def test_new_password_must_be_at_least_8_chars(anon_client):
    r = await anon_client.post(
        "/api/v1/auth/reset-password", json={"email": "a@example.com", "code": "123456", "new_password": "short"}
    )
    assert r.status_code == 422


async def test_change_password_requires_login(anon_client):
    r = await anon_client.post("/api/v1/auth/change-password", json={"new_password": "newpassword1"})
    assert r.status_code in (401, 403)


# --- against a real database (skipped without TEST_DATABASE_URL) -----------

REGISTER = {"full_name": "Ada", "email": "ada@example.com", "password": "oldpassword1"}


async def _login(client, password):
    return await client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": password})


async def test_forgot_then_reset_password(client):
    await client.post("/api/v1/auth/register", json=REGISTER)

    r = await client.post("/api/v1/auth/forgot-password", json={"email": "ada@example.com"})
    code = r.json()["dev_reset_code"]
    assert code

    bad = await client.post(
        "/api/v1/auth/reset-password",
        json={"email": "ada@example.com", "code": "000000", "new_password": "brandnewpass1"},
    )
    assert bad.status_code == 400

    ok = await client.post(
        "/api/v1/auth/reset-password",
        json={"email": "ada@example.com", "code": code, "new_password": "brandnewpass1"},
    )
    assert ok.status_code == 204
    assert (await _login(client, "brandnewpass1")).status_code == 200
    assert (await _login(client, "oldpassword1")).status_code == 401

    # the code is single-use
    again = await client.post(
        "/api/v1/auth/reset-password",
        json={"email": "ada@example.com", "code": code, "new_password": "anotherpass12"},
    )
    assert again.status_code == 400


async def test_change_password(client):
    reg = await client.post("/api/v1/auth/register", json=REGISTER)
    headers = {"Authorization": f"Bearer {reg.json()['access_token']}"}

    wrong = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "nope", "new_password": "brandnewpass1"},
        headers=headers,
    )
    assert wrong.status_code == 400

    ok = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "oldpassword1", "new_password": "brandnewpass1"},
        headers=headers,
    )
    assert ok.status_code == 204
    assert (await _login(client, "brandnewpass1")).status_code == 200
