import enum
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Numeric,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

Money = Numeric(18, 2)


class Base(DeclarativeBase):
    pass


class TransactionType(enum.StrEnum):
    DEPOSIT = "DEPOSIT"
    WITHDRAWAL = "WITHDRAWAL"


class Account(Base):
    __tablename__ = "accounts"
    __table_args__ = (CheckConstraint("balance >= 0", name="ck_accounts_balance_non_negative"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    owner_name: Mapped[str] = mapped_column(String(100))
    currency: Mapped[str] = mapped_column(String(3), default="USD")
    balance: Mapped[Decimal] = mapped_column(Money, default=Decimal("0.00"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_transactions_amount_positive"),
        CheckConstraint("balance_after >= 0", name="ck_transactions_balance_after_non_negative"),
        UniqueConstraint(
            "account_id", "idempotency_key", name="uq_transactions_account_idempotency_key"
        ),
        Index("ix_transactions_account_id_created_at", "account_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id", ondelete="RESTRICT"))
    type: Mapped[TransactionType] = mapped_column(Enum(TransactionType, name="transaction_type"))
    amount: Mapped[Decimal] = mapped_column(Money)
    balance_after: Mapped[Decimal] = mapped_column(Money)
    idempotency_key: Mapped[str | None] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
