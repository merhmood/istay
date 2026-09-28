from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "dev"
    database_url: str = "postgresql+asyncpg://staynaija:staynaija@localhost:5432/staynaija"

    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    paystack_secret_key: str = "sk_test_replace_me"
    paystack_public_key: str = "pk_test_replace_me"

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
    # Prefixed onto every uploaded file's URL (see api/v1/users.py::_save_upload)
    # so a listing photo or verification document is a real fetchable URL, not
    # a host-less path like "/uploads/...". Matches the mobile clients' own
    # ApiConfig.baseUrl default - both point at the same backend.
    public_base_url: str = "http://localhost:8000"

    @property
    def is_dev(self) -> bool:
        return self.env.lower() == "dev"

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
