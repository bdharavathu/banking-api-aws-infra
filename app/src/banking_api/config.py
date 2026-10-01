from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    environment: str = "local"
    app_version: str = "dev"
    log_level: str = "INFO"
    enable_docs: bool = False

    host: str = "0.0.0.0"  # noqa: S104  # nosec B104
    port: int = 8000
    forwarded_allow_ips: str = "*"

    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "banking"
    db_user: str = "banking"
    db_password: SecretStr = SecretStr("")
    db_sslmode: str = "verify-full"
    db_sslrootcert: str = "/app/certs/rds-global-bundle.pem"
    db_pool_size: int = 5
    db_max_overflow: int = 5

    api_key_hashes: SecretStr = SecretStr("")

    def database_url(self) -> URL:
        query = {"sslmode": self.db_sslmode}
        if self.db_sslmode in ("verify-ca", "verify-full"):
            query["sslrootcert"] = self.db_sslrootcert
        return URL.create(
            "postgresql+psycopg",
            username=self.db_user,
            password=self.db_password.get_secret_value(),
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            query=query,
        )

    def api_key_hash_set(self) -> frozenset[str]:
        raw = self.api_key_hashes.get_secret_value()
        return frozenset(h.strip().lower() for h in raw.split(",") if h.strip())


@lru_cache
def get_settings() -> Settings:
    return Settings()
