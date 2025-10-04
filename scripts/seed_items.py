#!/usr/bin/env python3
import json, os, sys, time
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

API_FILE = "infra/terraform/terraform_api_url.txt"
if not os.path.exists(API_FILE):
    print(f"ERROR: {API_FILE} not found. Run: make outputs", file=sys.stderr)
    sys.exit(1)
API = open(API_FILE).read().strip()

# Default catalog (feel free to edit)
CATALOG = [
    {"sku": "ESP-001", "name": "Espresso",        "price": 3.50, "stock": 10},
    {"sku": "AME-001", "name": "Americano",       "price": 3.75, "stock": 12},
    {"sku": "LAT-001", "name": "Latte",           "price": 4.50, "stock": 8},
    {"sku": "CAP-001", "name": "Cappuccino",      "price": 4.25, "stock": 7},
    {"sku": "ICL-001", "name": "Iced Latte",      "price": 4.75, "stock": 6},
    {"sku": "COL-001", "name": "Cold Brew",       "price": 4.00, "stock": 5},
    {"sku": "FRP-001", "name": "Frappuccino",     "price": 5.00, "stock": 4},
    {"sku": "CRO-001", "name": "Croissant",       "price": 2.75, "stock": 15},
    {"sku": "MUF-001", "name": "Blueberry Muffin","price": 2.50, "stock": 20},
    {"sku": "BAG-001", "name": "Bagel",           "price": 1.75, "stock": 18},
]

def call(path, method="GET", data=None):
    url = API + path
    req = Request(url, method=method)
    if data is not None:
        body = json.dumps(data).encode()
        req.add_header("Content-Type", "application/json")
        req.data = body
    try:
        with urlopen(req, timeout=10) as r:
            txt = r.read().decode()
            return r.status, (json.loads(txt) if txt else None)
    except HTTPError as e:
        txt = e.read().decode()
        try:
            return e.code, json.loads(txt)
        except Exception:
            return e.code, {"raw": txt}
    except URLError as e:
        return 0, {"error": str(e)}

def main():
    print(f"☕ CafeOps API: {API}")
    update_mode = "--update" in sys.argv
    print(f"API: {API}")
    # fetch existing items
    code, body = call("/items")
    if code != 200 or not isinstance(body, list):
        print(f"Failed to load /items: HTTP {code} {body}", file=sys.stderr)
        sys.exit(2)
    existing = {it.get("sku") for it in body}
    print(f"Found {len(existing)} existing items.")

    created, updated, skipped, failed = 0, 0, 0, 0
    for it in CATALOG:
        sku = it["sku"]
        if sku in existing and not update_mode:
            skipped += 1
            print(f"- {sku} exists -> skip")
            continue
        if sku in existing and update_mode:
            # update price/stock only
            payload = {}
            for k in ("name","price","stock"):
                if k in it: payload[k] = it[k]
            code, resp = call(f"/items/{sku}", method="PUT", data=payload)
            if 200 <= code < 300:
                updated += 1
                print(f"~ {sku} updated (HTTP {code})")
            else:
                failed += 1
                print(f"! {sku} update failed (HTTP {code}) -> {resp}")
            continue

        code, resp = call("/items", method="POST", data=it)
        if 200 <= code < 300:
            created += 1
            print(f"+ {sku} created (HTTP {code})")
        else:
            failed += 1
            print(f"! {sku} create failed (HTTP {code}) -> {resp}")

        # tiny pause to make logs nicer
        time.sleep(0.05)

    print(f"\nDone. created={created} updated={updated} skipped={skipped} failed={failed}")
    sys.exit(0 if failed == 0 else 3)

if __name__ == "__main__":
    main()
