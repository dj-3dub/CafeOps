#!/usr/bin/env bash
set -euo pipefail

API_URL_FILE="$(dirname "$0")/../infra/terraform_api_url.txt"
if [[ -f "$API_URL_FILE" ]]; then
  API="$(cat "$API_URL_FILE")"
else
  echo "API URL not found. Run: make outputs"
  exit 1
fi

case "${1:-}" in
  list_items)
    curl -s "$API/items" | jq .
    ;;
  new_order)
    curl -s -X POST "$API/orders" -H "Content-Type: application/json" -d '{"items":[{"sku":"ESP-001","qty":2}]}' | jq .
    ;;
  *)
    echo "Usage: $0 {list_items|new_order}"
    ;;
esac
