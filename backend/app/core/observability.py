"""Rate limiting, request logging and error monitoring.

Kept in one module so main.py only has to call `setup_observability(app)`.
"""

import json
import logging
import time
import uuid

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

from app.core.config import settings

logger = logging.getLogger("staynaija.request")


def _client_ip(request: Request) -> str:
    # Behind Magic Containers / a load balancer the socket peer is the proxy;
    # the real client is the first hop in X-Forwarded-For.
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return get_remote_address(request)


limiter = Limiter(
    key_func=_client_ip,
    default_limits=[settings.rate_limit_default],
    enabled=settings.rate_limit_enabled,
)

# Tighter limits for the endpoints worth brute-forcing or spamming (password
# guessing, OTP SMS cost, account creation).
AUTH_LIMIT = "10/minute"
OTP_LIMIT = "5/minute"


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {"level": record.levelname, "msg": record.getMessage()}
        extra = getattr(record, "fields", None)
        if extra:
            payload.update(extra)
        return json.dumps(payload, default=str)


def _configure_logging() -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(_JsonFormatter())
    logger.handlers = [handler]
    logger.setLevel(logging.INFO)
    logger.propagate = False


def _configure_sentry() -> None:
    if not settings.sentry_dsn:
        return
    import sentry_sdk

    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.env,
        traces_sample_rate=settings.sentry_traces_sample_rate,
        send_default_pii=False,
    )


def setup_observability(app: FastAPI) -> None:
    _configure_logging()
    _configure_sentry()

    app.state.limiter = limiter

    @app.exception_handler(RateLimitExceeded)
    async def _rate_limited(request: Request, exc: RateLimitExceeded) -> JSONResponse:
        return JSONResponse(
            status_code=429,
            content={"detail": "Too many requests. Please slow down and try again shortly."},
            headers={"Retry-After": "60"},
        )

    app.add_middleware(SlowAPIMiddleware)

    @app.middleware("http")
    async def _log_requests(request: Request, call_next):
        request_id = request.headers.get("x-request-id") or uuid.uuid4().hex[:12]
        started = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            response.headers["X-Request-ID"] = request_id
            return response
        except Exception:
            logger.exception("unhandled error", extra={"fields": {"request_id": request_id, "path": request.url.path}})
            raise
        finally:
            if request.url.path != "/health":
                logger.info(
                    "request",
                    extra={
                        "fields": {
                            "request_id": request_id,
                            "method": request.method,
                            "path": request.url.path,
                            "status": status_code,
                            "duration_ms": round((time.perf_counter() - started) * 1000, 1),
                            "client": _client_ip(request),
                        }
                    },
                )
