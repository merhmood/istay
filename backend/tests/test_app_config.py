from app.core.config import settings


async def test_demo_logins_follow_env(anon_client, monkeypatch):
    monkeypatch.setattr(settings, "show_demo_logins", None)
    monkeypatch.setattr(settings, "env", "dev")
    assert (await anon_client.get("/api/v1/config")).json()["show_demo_logins"] is True

    monkeypatch.setattr(settings, "env", "staging")
    assert (await anon_client.get("/api/v1/config")).json()["show_demo_logins"] is True

    monkeypatch.setattr(settings, "env", "production")
    assert (await anon_client.get("/api/v1/config")).json()["show_demo_logins"] is False


async def test_support_contacts_exposed_when_configured(anon_client, monkeypatch):
    monkeypatch.setattr(settings, "support_whatsapp", "2348012345678")
    monkeypatch.setattr(settings, "support_email", "")
    body = (await anon_client.get("/api/v1/config")).json()
    assert body["support_whatsapp"] == "2348012345678"
    assert body["support_email"] is None


async def test_demo_logins_explicit_override_wins(anon_client, monkeypatch):
    monkeypatch.setattr(settings, "env", "production")
    monkeypatch.setattr(settings, "show_demo_logins", True)
    assert (await anon_client.get("/api/v1/config")).json()["show_demo_logins"] is True
