import hashlib
import os
from collections.abc import Iterator
from pathlib import Path

import pytest

TEST_API_KEY = "test-api-key"

os.environ.setdefault("DB_HOST", "localhost")
os.environ.setdefault("DB_PORT", "5432")
os.environ.setdefault("DB_NAME", "banking_test")
os.environ.setdefault("DB_USER", "banking")
os.environ.setdefault("DB_PASSWORD", "banking")
os.environ.setdefault("DB_SSLMODE", "disable")
os.environ.setdefault("DB_POOL_SIZE", "10")
os.environ.setdefault("DB_MAX_OVERFLOW", "15")
os.environ["API_KEY_HASHES"] = hashlib.sha256(TEST_API_KEY.encode()).hexdigest()
os.environ["LOG_LEVEL"] = "DEBUG"

from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from banking_api.db import get_engine  # noqa: E402
from banking_api.main import app  # noqa: E402

ALEMBIC_INI = Path(__file__).resolve().parents[1] / "alembic.ini"


def alembic_config() -> Config:
    cfg = Config(str(ALEMBIC_INI))
    cfg.attributes["configure_logger"] = False
    return cfg


@pytest.fixture(scope="session", autouse=True)
def _migrated_database() -> Iterator[None]:
    cfg = alembic_config()
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")
    yield
    get_engine().dispose()


@pytest.fixture(autouse=True)
def _clean_tables() -> Iterator[None]:
    yield
    with get_engine().begin() as conn:
        conn.execute(text("TRUNCATE transactions, accounts"))


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(app, headers={"X-API-Key": TEST_API_KEY}) as c:
        yield c


@pytest.fixture
def anon_client() -> Iterator[TestClient]:
    with TestClient(app) as c:
        yield c


@pytest.fixture
def account_id(client: TestClient) -> str:
    resp = client.post("/v1/accounts", json={"owner_name": "Jane Doe", "currency": "USD"})
    assert resp.status_code == 201
    return str(resp.json()["id"])
