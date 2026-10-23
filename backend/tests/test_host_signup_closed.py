"""Host signup is closed to the public; hosts are onboarded by the iStay team."""


async def test_register_as_host_is_rejected(anon_client):
    r = await anon_client.post(
        "/api/v1/auth/register",
        json={"full_name": "Eve", "email": "eve@example.com", "password": "secret123", "is_host": True},
    )
    assert r.status_code == 403
    assert "iStay team" in r.json()["detail"]


async def test_creating_a_host_requires_admin(anon_client):
    r = await anon_client.post("/api/v1/admin/hosts", json={"email": "eve@example.com"})
    assert r.status_code in (401, 403)
