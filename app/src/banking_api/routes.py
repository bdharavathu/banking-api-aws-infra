import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from banking_api import services
from banking_api.config import get_settings
from banking_api.db import get_session
from banking_api.schemas import (
    AccountCreate,
    AccountOut,
    AmountRequest,
    BalanceOut,
    TransactionOut,
)
from banking_api.security import require_api_key

logger = logging.getLogger(__name__)

SessionDep = Annotated[Session, Depends(get_session)]
IdempotencyKey = Annotated[
    str | None,
    Header(
        min_length=1,
        max_length=64,
        pattern=r"^[A-Za-z0-9_.:-]+$",
        description="Client-generated key; retrying with the same key never double-posts.",
    ),
]

health_router = APIRouter(tags=["health"])
accounts_router = APIRouter(
    prefix="/v1/accounts", tags=["accounts"], dependencies=[Depends(require_api_key)]
)


@health_router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": get_settings().app_version}


@health_router.get("/ready")
def ready(session: SessionDep) -> dict[str, str]:
    try:
        session.execute(text("SELECT 1"))
    except SQLAlchemyError:
        logger.warning("readiness check failed", extra={"event": "db_unavailable"}, exc_info=True)
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Database unavailable") from None
    return {"status": "ready"}


@accounts_router.post("", status_code=status.HTTP_201_CREATED)
def create_account(body: AccountCreate, session: SessionDep) -> AccountOut:
    account = services.create_account(session, body.owner_name, body.currency)
    return AccountOut.model_validate(account)


@accounts_router.get("/{account_id}")
def get_account(account_id: UUID, session: SessionDep) -> AccountOut:
    return AccountOut.model_validate(services.get_account(session, account_id))


@accounts_router.get("/{account_id}/balance")
def get_balance(account_id: UUID, session: SessionDep) -> BalanceOut:
    account = services.get_account(session, account_id)
    return BalanceOut(account_id=account.id, currency=account.currency, balance=account.balance)


@accounts_router.get("/{account_id}/transactions")
def list_transactions(
    account_id: UUID,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[TransactionOut]:
    txns = services.list_transactions(session, account_id, limit)
    return [TransactionOut.model_validate(t) for t in txns]


@accounts_router.post("/{account_id}/deposit")
def deposit(
    account_id: UUID,
    body: AmountRequest,
    session: SessionDep,
    response: Response,
    idempotency_key: IdempotencyKey = None,
) -> TransactionOut:
    txn, replayed = services.deposit(session, account_id, body.amount, idempotency_key)
    if replayed:
        response.headers["Idempotent-Replayed"] = "true"
    return TransactionOut.model_validate(txn)


@accounts_router.post("/{account_id}/withdraw")
def withdraw(
    account_id: UUID,
    body: AmountRequest,
    session: SessionDep,
    response: Response,
    idempotency_key: IdempotencyKey = None,
) -> TransactionOut:
    txn, replayed = services.withdraw(session, account_id, body.amount, idempotency_key)
    if replayed:
        response.headers["Idempotent-Replayed"] = "true"
    return TransactionOut.model_validate(txn)
