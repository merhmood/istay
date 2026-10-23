from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "dev"
    database_url: str = "postgresql+asyncpg://staynaija:staynaija@localhost:5432/staynaija"

    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    flutterwave_secret_key: str = "FLWSECK_TEST-replace-me"
    flutterwave_public_key: str = "FLWPUBK_TEST-replace-me"
    # The "secret hash" set on the Flutterwave dashboard's webhook settings;
    # Flutterwave echoes it back in the `verif-hash` header of every webhook.
    # Empty means the webhook endpoint rejects everything.
    flutterwave_webhook_secret_hash: str = ""

    # Social sign-in. Comma-separated because a mobile app typically registers
    # a different OAuth client per platform (Android/iOS/web) that must all be
    # accepted here. Left empty by default - see services/social_auth.py: an
    # empty list means the audience check is skipped rather than rejecting
    # everything, which is the wrong failure mode during setup but the right
    # one is enforced the moment a real id is added here.
    google_client_ids_raw: str = ""
    apple_bundle_ids_raw: str = ""

    # Host-only commission: charged against the host's payout, never added on
    # top of what the guest pays - see services/pricing.py.
    platform_commission_percent: float = 3.5

    # Abuse protection - see app/core/observability.py. `rate_limit_default`
    # applies to every route; auth/OTP/payment routes get tighter limits of
    # their own. Limits are keyed by client IP, in-memory per process.
    rate_limit_enabled: bool = True
    rate_limit_default: str = "120/minute"

    # Error monitoring. Empty = Sentry stays off (local dev, tests).
    sentry_dsn: str = ""
    sentry_traces_sample_rate: float = 0.0

    # Whether the apps show the "demo logins" hint on their sign-in screens.
    # Unset = follow ENV (shown in dev and staging, hidden in production); set
    # SHOW_DEMO_LOGINS=true/false to force it either way.
    show_demo_logins: bool | None = None

    # Shown to prospective hosts on the host app's login screen ("Request host
    # access"). WhatsApp is digits only, with country code, e.g. 2348012345678.
    support_whatsapp: str = ""
    support_email: str = ""

    cors_origins: str = "*"
    upload_dir: str = "uploads"
    # Prefixed onto every uploaded file's URL (see services/storage.py) so a
    # listing photo or verification document is a real fetchable URL, not a
    # host-less path like "/uploads/...". Matches the mobile clients' own
    # ApiConfig.baseUrl default - both point at the same backend. Only used
    # for the local-disk storage fallback - see bunny_storage_configured.
    public_base_url: str = "http://localhost:8000"

    # Bunny Storage + a CDN pull zone in front, for listing photos and
    # verification documents - see services/storage.py. Left empty by
    # default: local dev writes to disk under `upload_dir` instead, so
    # running the app never requires a Bunny account. Production sets all
    # three, since local disk on Magic Containers doesn't survive a redeploy
    # and isn't shared across instances if it's ever scaled past one - see
    # docs/deploy-backend.md.
    bunny_storage_zone: str = ""
    bunny_storage_access_key: str = ""
    # The zone's storage.bunnycdn.com by default; a region code (e.g. "ny")
    # prefixes that instead for a region-pinned storage zone - see
    # https://docs.bunny.net/docs/storage-regions.
    bunny_storage_region: str = ""
    # The Pull Zone hostname (or mapped custom domain) files are actually
    # fetched back from - never the storage endpoint itself, which isn't
    # meant to serve traffic directly.
    bunny_storage_pull_zone_host: str = ""

    @property
    def is_dev(self) -> bool:
        return self.env.lower() == "dev"

    @property
    def demo_logins_enabled(self) -> bool:
        if self.show_demo_logins is not None:
            return self.show_demo_logins
        return self.env.lower() in ("dev", "staging", "stag")

    @property
    def bunny_storage_configured(self) -> bool:
        return bool(self.bunny_storage_zone and self.bunny_storage_access_key and self.bunny_storage_pull_zone_host)

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",")]

    @property
    def google_client_ids(self) -> list[str]:
        return [v.strip() for v in self.google_client_ids_raw.split(",") if v.strip()]

    @property
    def apple_bundle_ids(self) -> list[str]:
        return [v.strip() for v in self.apple_bundle_ids_raw.split(",") if v.strip()]


settings = Settings()
