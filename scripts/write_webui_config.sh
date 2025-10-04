#!/usr/bin/env bash
set -euo pipefail

API_FILE="infra/terraform/terraform_api_url.txt"
if [[ ! -f "$API_FILE" ]]; then
  echo "❌ $API_FILE not found. Run: make outputs"
  exit 1
fi

API="$(head -n1 "$API_FILE")"
: "${API:?API URL not found. Run: make outputs}"

cat > webui/config.js <<JS
window.API_BASE = "${API}";
JS

echo "✅ Wrote webui/config.js with API_BASE=${API}"
