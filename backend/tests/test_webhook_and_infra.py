import json
import logging

from app.core import observability


async def test_health(anon_client):
    r = await anon_client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


async def test_webhook_rejects_missing_signature(anon_client):
    r = await anon_client.post("/api/v1/payments/webhook", json={"data": {"tx_ref": "stn_x"}})
    assert r.status_code == 401


async def test_webhook_rejects_wrong_signature(anon_client):
    r = await anon_client.post(
        "/api/v1/payments/webhook", json={"data": {"tx_ref": "stn_x"}}, headers={"verif-hash": "nope"}
    )
    assert r.status_code == 401


async def test_response_carries_request_id(anon_client):
    r = await anon_client.get("/health", headers={"x-request-id": "abc123"})
    assert r.headers["x-request-id"] == "abc123"


def test_json_log_formatter_includes_fields():
    record = logging.LogRecord("t", logging.INFO, "f", 1, "request", None, None)
    record.fields = {"status": 200}
    out = json.loads(observability._JsonFormatter().format(record))
    assert out == {"level": "INFO", "msg": "request", "status": 200}


def test_client_ip_prefers_forwarded_for():
    class Req:
        headers = {"x-forwarded-for": "1.2.3.4, 10.0.0.1"}

    assert observability._client_ip(Req()) == "1.2.3.4"
