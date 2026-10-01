from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool

from banking_api.config import get_settings
from banking_api.models import Base

config = context.config
if config.config_file_name is not None and config.attributes.get("configure_logger", True):
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_online() -> None:
    engine = create_engine(get_settings().database_url(), poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            connection.exec_driver_sql("SELECT pg_advisory_xact_lock(727274)")
            context.run_migrations()


if context.is_offline_mode():
    raise SystemExit("Offline migrations are not supported; run against a live database.")
run_migrations_online()
