import uuid

import pytest
from fastapi.testclient import TestClient


def balance(client: TestClient, account_id: str) -> str:
    return str(client.get(f"/v1/accounts/{account_id}/balance").json()["balance"])


def test_health(anon_client: TestClient) -> None:
    assert anon_client.get("/health").status_code == 200
    assert anon_client.get("/ready").status_code == 200


def test_requires_api_key(anon_client: TestClient) -> None:
    assert anon_client.post("/v1/accounts", json={"owner_name": "x"}).status_code == 401
    resp = anon_client.get(f"/v1/accounts/{uuid.uuid4()}", headers={"X-API-Key": "wrong"})
    assert resp.status_code == 401


def test_create_account(client: TestClient) -> None:
    resp = client.post("/v1/accounts", json={"owner_name": "Jane Doe"})
    assert resp.status_code == 201
    body = resp.json()
    assert body["balance"] == "0.00"
    assert client.get(f"/v1/accounts/{body['id']}").json()["owner_name"] == "Jane Doe"


def test_deposit_and_withdraw(client: TestClient, account_id: str) -> None:
    resp = client.post(f"/v1/accounts/{account_id}/deposit", json={"amount": "100.5"})
    assert resp.status_code == 200
    assert resp.json()["amount"] == "100.50"
    assert resp.json()["balance_after"] == "100.50"

    resp = client.post(f"/v1/accounts/{account_id}/withdraw", json={"amount": "40.25"})
    assert resp.status_code == 200
    assert balance(client, account_id) == "60.25"

    txns = client.get(f"/v1/accounts/{account_id}/transactions").json()
    assert sorted(t["type"] for t in txns) == ["DEPOSIT", "WITHDRAWAL"]


def test_overdraft_rejected(client: TestClient, account_id: str) -> None:
    client.post(f"/v1/accounts/{account_id}/deposit", json={"amount": "10.00"})
    resp = client.post(f"/v1/accounts/{account_id}/withdraw", json={"amount": "10.01"})
    assert resp.status_code == 409
    assert balance(client, account_id) == "10.00"


@pytest.mark.parametrize("amount", ["0", "-5.00", "1.001", "1000000.01", "abc"])
def test_invalid_amount(client: TestClient, account_id: str, amount: str) -> None:
    resp = client.post(f"/v1/accounts/{account_id}/deposit", json={"amount": amount})
    assert resp.status_code == 422


def test_unknown_account(client: TestClient) -> None:
    assert client.get(f"/v1/accounts/{uuid.uuid4()}/balance").status_code == 404


def test_idempotent_retry(client: TestClient, account_id: str) -> None:
    headers = {"Idempotency-Key": "abc-123"}
    first = client.post(
        f"/v1/accounts/{account_id}/deposit", json={"amount": "25.00"}, headers=headers
    )
    second = client.post(
        f"/v1/accounts/{account_id}/deposit", json={"amount": "25.00"}, headers=headers
    )
    assert first.json()["id"] == second.json()["id"]
    assert balance(client, account_id) == "25.00"


def test_internal_errors_are_not_leaked(
    client: TestClient, account_id: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from banking_api import services

    def boom(*_: object) -> None:
        raise RuntimeError("secret internal detail")

    monkeypatch.setattr(services, "get_account", boom)
    resp = client.get(f"/v1/accounts/{account_id}")
    assert resp.status_code == 500
    assert "secret" not in resp.text
