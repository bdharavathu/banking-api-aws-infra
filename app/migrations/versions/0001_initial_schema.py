"""Initial schema: accounts and transaction ledger

Revision ID: 0001
Revises:
Create Date: 2026-10-01
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

transaction_type = sa.Enum("DEPOSIT", "WITHDRAWAL", name="transaction_type")


def upgrade() -> None:
    op.create_table(
        "accounts",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("owner_name", sa.String(100), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("balance", sa.Numeric(18, 2), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("balance >= 0", name="ck_accounts_balance_non_negative"),
    )
    op.create_table(
        "transactions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "account_id",
            sa.Uuid(),
            sa.ForeignKey("accounts.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("type", transaction_type, nullable=False),
        sa.Column("amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("balance_after", sa.Numeric(18, 2), nullable=False),
        sa.Column("idempotency_key", sa.String(64), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("amount > 0", name="ck_transactions_amount_positive"),
        sa.CheckConstraint("balance_after >= 0", name="ck_transactions_balance_after_non_negative"),
        sa.UniqueConstraint(
            "account_id", "idempotency_key", name="uq_transactions_account_idempotency_key"
        ),
    )
    op.create_index(
        "ix_transactions_account_id_created_at", "transactions", ["account_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_transactions_account_id_created_at", table_name="transactions")
    op.drop_table("transactions")
    op.drop_table("accounts")
    transaction_type.drop(op.get_bind(), checkfirst=True)
