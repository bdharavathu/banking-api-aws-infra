import logging
import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from banking_api.models import Account, Transaction, TransactionType

logger = logging.getLogger(__name__)


class AccountNotFoundError(Exception):
    pass


class InsufficientFundsError(Exception):
    pass


class IdempotencyConflictError(Exception):
    pass


def create_account(session: Session, owner_name: str, currency: str) -> Account:
    account = Account(owner_name=owner_name, currency=currency, balance=Decimal("0.00"))
    session.add(account)
    session.commit()
    logger.info(
        "account created", extra={"event": "account_created", "account_id": str(account.id)}
    )
    return account


def get_account(session: Session, account_id: uuid.UUID) -> Account:
    account = session.get(Account, account_id)
    if account is None:
        raise AccountNotFoundError
    return account


def list_transactions(session: Session, account_id: uuid.UUID, limit: int) -> list[Transaction]:
    get_account(session, account_id)
    stmt = (
        select(Transaction)
        .where(Transaction.account_id == account_id)
        .order_by(Transaction.created_at.desc(), Transaction.id)
        .limit(limit)
    )
    return list(session.scalars(stmt))


def deposit(
    session: Session, account_id: uuid.UUID, amount: Decimal, idempotency_key: str | None
) -> tuple[Transaction, bool]:
    return _apply(session, account_id, TransactionType.DEPOSIT, amount, idempotency_key)


def withdraw(
    session: Session, account_id: uuid.UUID, amount: Decimal, idempotency_key: str | None
) -> tuple[Transaction, bool]:
    return _apply(session, account_id, TransactionType.WITHDRAWAL, amount, idempotency_key)


def _apply(
    session: Session,
    account_id: uuid.UUID,
    txn_type: TransactionType,
    amount: Decimal,
    idempotency_key: str | None,
) -> tuple[Transaction, bool]:
    amount = amount.quantize(Decimal("0.01"))
    try:
        account = session.execute(
            select(Account).where(Account.id == account_id).with_for_update()
        ).scalar_one_or_none()
        if account is None:
            raise AccountNotFoundError

        if idempotency_key is not None:
            existing = session.execute(
                select(Transaction).where(
                    Transaction.account_id == account_id,
                    Transaction.idempotency_key == idempotency_key,
                )
            ).scalar_one_or_none()
            if existing is not None:
                session.rollback()
                if existing.type != txn_type or existing.amount != amount:
                    raise IdempotencyConflictError
                logger.info(
                    "idempotent replay",
                    extra={"event": "idempotent_replay", "transaction_id": str(existing.id)},
                )
                return existing, True

        if txn_type is TransactionType.DEPOSIT:
            new_balance = account.balance + amount
        else:
            new_balance = account.balance - amount
            if new_balance < 0:
                logger.info(
                    "withdrawal rejected",
                    extra={
                        "event": "withdrawal_rejected",
                        "reason": "insufficient_funds",
                        "account_id": str(account_id),
                    },
                )
                raise InsufficientFundsError

        account.balance = new_balance
        txn = Transaction(
            account_id=account_id,
            type=txn_type,
            amount=amount,
            balance_after=new_balance,
            idempotency_key=idempotency_key,
        )
        session.add(txn)
        session.commit()
    except Exception:
        session.rollback()
        raise

    logger.info(
        "transaction applied",
        extra={
            "event": txn_type.value.lower(),
            "account_id": str(account_id),
            "transaction_id": str(txn.id),
        },
    )
    return txn, False
