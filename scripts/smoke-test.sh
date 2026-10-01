#!/usr/bin/env bash
# Usage: API_URL=https://... API_KEY=... [EXPECTED_VERSION=sha] [INSECURE=1] scripts/smoke-test.sh
set -euo pipefail

: "${API_URL:?API_URL is required}"
: "${API_KEY:?API_KEY is required}"

curl_opts=(--silent --show-error --max-time 10 --retry 5 --retry-delay 3 --retry-all-errors)
[[ "${INSECURE:-0}" == "1" ]] && curl_opts+=(--insecure)

call() {
  local method=$1 path=$2 body=${3:-}
  local args=("${curl_opts[@]}" -X "$method" -H "X-API-Key: $API_KEY" -H "Content-Type: application/json"
    -o /tmp/smoke-body -w '%{http_code}')
  [[ -n "$body" ]] && args+=(-d "$body")
  curl "${args[@]}" "$API_URL$path"
}

json() { python3 -c "import json,sys; print(json.load(open('/tmp/smoke-body'))$1)"; }

expect() {
  local want=$1 got=$2 what=$3
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $what (expected $want, got $got)"
    cat /tmp/smoke-body; echo
    exit 1
  fi
  echo "ok   $what"
}

expect 200 "$(call GET /health)" "GET /health"
if [[ -n "${EXPECTED_VERSION:-}" ]]; then
  expect "$EXPECTED_VERSION" "$(json '["version"]')" "running version"
fi
expect 200 "$(call GET /ready)" "GET /ready (database reachable)"

http_code=$(curl "${curl_opts[@]}" -o /dev/null -w '%{http_code}' "$API_URL/v1/accounts/00000000-0000-0000-0000-000000000000")
expect 401 "$http_code" "request without API key rejected"

expect 201 "$(call POST /v1/accounts '{"owner_name":"Smoke Test"}')" "create account"
account_id=$(json '["id"]')

expect 200 "$(call POST "/v1/accounts/$account_id/deposit" '{"amount":"100.00"}')" "deposit 100.00"
expect 200 "$(call POST "/v1/accounts/$account_id/withdraw" '{"amount":"30.50"}')" "withdraw 30.50"
expect 409 "$(call POST "/v1/accounts/$account_id/withdraw" '{"amount":"1000.00"}')" "overdraft rejected"
expect 200 "$(call GET "/v1/accounts/$account_id/balance")" "get balance"
expect "69.50" "$(json '["balance"]')" "balance is 69.50"

echo "smoke test passed"
