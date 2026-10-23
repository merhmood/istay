"""Admin host onboarding against a real database (skipped without TEST_DATABASE_URL)."""

from app.core.security import hash_password
from app.models.user import User


async def _admin_headers(client, db_session):
    db_session.add(
        User(full_name="Admin", email="admin@example.com", hashed_password=hash_password("adminpass1"), is_admin=True)
    )
    await db_session.commit()
    login = await client.post("/api/v1/auth/login", json={"email": "admin@example.com", "password": "adminpass1"})
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


async def test_admin_creates_host_who_must_change_password(client, db_session):
    headers = await _admin_headers(client, db_session)

    created = await client.post(
        "/api/v1/admin/hosts",
        json={"email": "host@example.com", "full_name": "Host One", "password": "temp-pass-1"},
        headers=headers,
    )
    assert created.status_code == 201
    body = created.json()
    assert body["is_host"] is True
    assert body["verification_status"] == "verified"
    assert body["must_change_password"] is True

    login = await client.post("/api/v1/auth/login", json={"email": "host@example.com", "password": "temp-pass-1"})
    assert login.status_code == 200
    token = login.json()["access_token"]
    assert login.json()["user"]["must_change_password"] is True

    changed = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "temp-pass-1", "new_password": "my-own-pass-1"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert changed.status_code == 204
    me = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["must_change_password"] is False


async def test_admin_lists_hosts(client, db_session):
    headers = await _admin_headers(client, db_session)
    await client.post(
        "/api/v1/admin/hosts",
        json={"email": "host@example.com", "full_name": "Host One", "password": "temp-pass-1"},
        headers=headers,
    )
    r = await client.get("/api/v1/admin/hosts", headers=headers)
    assert [h["email"] for h in r.json()] == ["host@example.com"]
