"""Needs TEST_DATABASE_URL (see conftest.py)."""

REGISTER = {"full_name": "Ada", "email": "ada@example.com", "password": "secret123"}


async def test_register_login_and_me(client):
    reg = await client.post("/api/v1/auth/register", json=REGISTER)
    assert reg.status_code == 201

    dup = await client.post("/api/v1/auth/register", json=REGISTER)
    assert dup.status_code == 409

    login = await client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": "secret123"})
    assert login.status_code == 200
    token = login.json()["access_token"]

    me = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "ada@example.com"


async def test_login_wrong_password_rejected(client):
    await client.post("/api/v1/auth/register", json=REGISTER)
    r = await client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": "wrong"})
    assert r.status_code == 401
