from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal

from banking_api import services
from banking_api.db import get_sessionmaker


def test_parallel_withdrawals_never_overdraw() -> None:
    with get_sessionmaker()() as session:
        account = services.create_account(session, "Concurrent", "USD")
        services.deposit(session, account.id, Decimal("100.00"), None)

    def withdraw(_: int) -> bool:
        with get_sessionmaker()() as session:
            try:
                services.withdraw(session, account.id, Decimal("10.00"), None)
            except services.InsufficientFundsError:
                return False
            return True

    with ThreadPoolExecutor(max_workers=20) as pool:
        results = list(pool.map(withdraw, range(25)))

    assert results.count(True) == 10
    with get_sessionmaker()() as session:
        assert services.get_account(session, account.id).balance == Decimal("0.00")
