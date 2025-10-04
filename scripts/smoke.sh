echo "=== CafeOps Smoke Test ===" >&2
#!/usr/bin/env bash
set -euo pipefail

# --- deps ---
command -v jq >/dev/null 2>&1 || { echo "Installing jq..." >&2; sudo apt-get update && sudo apt-get install -y jq >/dev/null; }

# --- API base URL ---
if [[ -f infra/terraform/terraform_api_url.txt ]]; then
  API="$(head -n1 infra/terraform/terraform_api_url.txt)"
else
  API="$(make -s outputs | head -n1)"
fi
[[ -n "${API:-}" ]] || { echo "❌ API base URL is empty. Run: make outputs" >&2; exit 1; }

echo "🔗 Using API: $API" >&2
curl -sS http://localhost:4566/_localstack/health | jq .services.apigateway >/dev/null 2>&1 \
  && echo "✅ LocalStack is up" >&2 || echo "⚠️  Couldn't confirm LocalStack health (continuing)" >&2

pass() { echo "✅ $*" >&2; }
fail() { echo "❌ $*" >&2; exit 1; }

# curl wrapper writes logs to stderr and echoes only status to stdout
req() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1-}"
  local url="${API}${path}"

  local resp status body
  if [[ -n "$data" ]]; then
    resp="$(curl -sS -w $'\n%{http_code}' -X "$method" "$url" -H 'Content-Type: application/json' -d "$data")" || true
  else
    resp="$(curl -sS -w $'\n%{http_code}' -X "$method" "$url")" || true
  fi
  status="$(echo "$resp" | tail -n1)"
  body="$(echo "$resp" | sed '$d')"

  echo "→ $method $path  (HTTP $status)" >&2
  if [[ -n "$body" ]]; then echo "$body" | jq . >/dev/null 2>&1 && echo "$body" | jq . >&2 || echo "$body" >&2; fi
  echo >&2

  echo "$status"
}

expect_2xx() {
  local status="$1"; local msg="$2"
  [[ "$status" =~ ^2[0-9][0-9]$ ]] && pass "$msg" || fail "$msg (HTTP $status)"
}

echo "=== Inventory API Smoke Test ===" >&2

st="$(req GET /items)";           expect_2xx "$st" "GET /items responded"
st="$(req POST /items '{"sku":"ESP-001","name":"Espresso","price":3.5,"stock":10}')" ; expect_2xx "$st" "POST /items created/ok"
st="$(req GET /items/ESP-001)";   expect_2xx "$st" "GET /items/ESP-001 returned"
st="$(req PUT /items/ESP-001 '{"price":3.75,"stock":12}')" ; expect_2xx "$st" "PUT /items/ESP-001 updated"
st="$(req POST /stock/in  '{"sku":"ESP-001","qty":5,"reason":"delivery"}')" ; expect_2xx "$st" "POST /stock/in ok"
st="$(req POST /stock/out '{"sku":"ESP-001","qty":3,"reason":"sale"}')"     ; expect_2xx "$st" "POST /stock/out ok"
st="$(req POST /orders    '{"items":[{"sku":"ESP-001","qty":2}]}' )"        ; expect_2xx "$st" "POST /orders ok"
st="$(req GET /orders)";          expect_2xx "$st" "GET /orders ok"

# Negative stock should fail (non-2xx expected)
st="$(req POST /stock/out '{"sku":"ESP-001","qty":9999,"reason":"oops"}')"
if [[ "$st" =~ ^2[0-9][0-9]$ ]]; then
  echo "⚠️  Expected failure on huge stock-out, but got 2xx" >&2
else
  pass "Negative stock guard triggered (HTTP $st)"
fi

echo "🎉 Smoke test completed." >&2
