#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8082}"          # override with: PORT=9090 ./scripts/test_cafeops.sh
TF_DIR="infra/terraform"
OUT_FILE="${TF_DIR}/terraform_api_url.txt"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1" >&2; exit 2; }; }

echo "☕ CafeOps — End-to-End Test (UI on :${PORT})"

# --- Check deps ---
need curl
need jq
need python3
need terraform

# --- Ensure Terraform is ready & get API URL ---
echo "ℹ️  Initializing Terraform (if needed) ..."
terraform -chdir="$TF_DIR" init -reconfigure -input=false >/dev/null
API="$(terraform -chdir="$TF_DIR" output -raw api_endpoint)"
echo "✅ API endpoint: $API"

# --- Write webui/config.js for the UI ---
mkdir -p webui
printf 'window.API_BASE = "%s";\n' "$API" > webui/config.js
echo "✅ Wrote webui/config.js"

# --- Start static server on PORT (and stop it on exit) ---
echo "ℹ️  Starting local web server on :$PORT ..."
pushd webui >/dev/null
if lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "⚠️  Port $PORT already in use — NOT starting a new server."
  UI_PID=""
else
  python3 -m http.server "$PORT" >/dev/null 2>&1 &
  UI_PID=$!
  echo "✅ Web server PID: $UI_PID"
fi
popd >/dev/null

cleanup() {
  [[ -n "${UI_PID:-}" ]] && kill "$UI_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --- Check UI is reachable ---
echo "ℹ️  Checking http://localhost:$PORT ..."
curl -sI "http://localhost:$PORT" | head -n1

# --- Preflight OPTIONS check (browser-style CORS probe) ---
echo "ℹ️  CORS preflight to /items ..."
PRE=$(curl -s -i -X OPTIONS "$API/items" \
  -H "Origin: http://localhost:$PORT" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type")
echo "$PRE" | head -n 15

ALLOW_ORIGIN=$(echo "$PRE" | grep -i '^Access-Control-Allow-Origin:' | awk '{print $2}' | tr -d '\r')
ALLOW_METHODS=$(echo "$PRE" | grep -i '^Access-Control-Allow-Methods:' | cut -d' ' -f2- | tr -d '\r')
ALLOW_HEADERS=$(echo "$PRE" | grep -i '^Access-Control-Allow-Headers:' | cut -d' ' -f2- | tr -d '\r')
if [[ -z "$ALLOW_ORIGIN" || -z "$ALLOW_METHODS" || -z "$ALLOW_HEADERS" ]]; then
  echo "❌ CORS headers missing — browser POSTs may fail. Fix API Gateway OPTIONS & Lambda CORS." >&2
  exit 3
fi
echo "✅ CORS OK (Origin=${ALLOW_ORIGIN:-?})"

# --- Run smoke test (API endpoints) ---
if [[ -x scripts/smoke.sh ]]; then
  echo "ℹ️  Running smoke test ..."
  if ./scripts/smoke.sh; then
    echo "✅ Smoke test passed"
  else
    echo "❌ Smoke test failed" >&2
    exit 4
  fi
else
  echo "⚠️  scripts/smoke.sh not found or not executable; skipping smoke test."
fi

# --- Seed items (idempotent) ---
if [[ -f scripts/seed_items.py ]]; then
  echo "ℹ️  Seeding items (update mode) ..."
  python3 scripts/seed_items.py --update || true
else
  echo "⚠️  scripts/seed_items.py not found; skipping seed."
fi

# --- Confirm data shows up ---
echo "ℹ️  GET /items ..."
curl -s "$API/items" | jq -r '.[] | "\(.sku)\t\(.name)\t$" + (try (.price|tostring) catch "") + "\t" + (try (.stock|tostring) catch "")' | sed 's/\t/    /g' | sed -n '1,10p'
echo "✅ Test complete — open: http://localhost:$PORT"
