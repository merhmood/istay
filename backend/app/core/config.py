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
