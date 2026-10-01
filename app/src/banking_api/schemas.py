from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from banking_api.models import TransactionType

MAX_TRANSACTION_AMOUNT = Decimal("1000000.00")

Amount = Annotated[
    Decimal,
    Field(
        gt=0,
        le=MAX_TRANSACTION_AMOUNT,
        max_digits=18,
        decimal_places=2,
        examples=["100.00"],
    ),
]


class AccountCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    owner_name: str = Field(min_length=1, max_length=100, examples=["Jane Doe"])
    currency: str = Field(default="USD", pattern=r"^[A-Z]{3}$", examples=["USD"])


class AmountRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    amount: Amount


class AccountOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    owner_name: str
    currency: str
    balance: Decimal
    created_at: datetime
    updated_at: datetime


class BalanceOut(BaseModel):
    account_id: UUID
    currency: str
    balance: Decimal


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    account_id: UUID
    type: TransactionType
    amount: Decimal
    balance_after: Decimal
    created_at: datetime
