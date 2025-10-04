from common.dynamodb import table, json_dumps
import json, os
from decimal import Decimal

ITEMS_TABLE = os.environ.get("ITEMS_TABLE", "Items")

CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,Authorization"
}

def _response(status, body):
    headers = {"Content-Type": "application/json", **CORS}
    return {"statusCode": status, "headers": headers, "body": json_dumps(body)}

def _normalize(event):
    rc = event.get("requestContext", {})
    body = event.get("body")
    # HTTP API v2
    if isinstance(rc, dict) and rc.get("http"):
        method = rc["http"].get("method")
        path = event.get("rawPath") or event.get("path", "")
        return method, path, body
    # REST API v1 (stage prefix)
    method = event.get("httpMethod")
    path = event.get("path", "") or ""
    stage = rc.get("stage")
    if stage and path.startswith(f"/{stage}"):
        path = path[len(stage) + 1 :]
    return method, path or "/", body

def handler(event, context):
    method, path, body = _normalize(event)

    # CORS preflight
    if method == "OPTIONS":
        return _response(200, {})

    if path.startswith("/items/"):
        sku = path.split("/items/")[1]
        if method == "GET":
            return get_item(sku)
        elif method == "PUT":
            data = json.loads(body or "{}")
            return update_item(sku, data)
        elif method == "DELETE":
            return delete_item(sku)
        else:
            return _response(405, {"error": "Method not allowed"})

    if path == "/items":
        if method == "GET":
            return list_items()
        elif method == "POST":
            data = json.loads(body or "{}")
            return create_item(data)
        else:
            return _response(405, {"error": "Method not allowed"})

    return _response(404, {"error": "Not found"})

def list_items():
    tbl = table(ITEMS_TABLE)
    resp = tbl.scan(Limit=100)
    return _response(200, resp.get("Items", []))

def get_item(sku: str):
    tbl = table(ITEMS_TABLE)
    resp = tbl.get_item(Key={"sku": sku})
    if "Item" not in resp:
        return _response(404, {"error": "Item not found"})
    return _response(200, resp["Item"])

def _to_decimal(val):
    if isinstance(val, (float, int)):
        return Decimal(str(val))
    if isinstance(val, str):
        try:
            return Decimal(val)
        except Exception:
            return val
    return val

def _normalize_item_numbers(d: dict) -> dict:
    out = dict(d)
    if "price" in out:
        out["price"] = _to_decimal(out["price"])
    if "stock" in out:
        out["stock"] = int(out["stock"])
    return out

def create_item(data: dict):
    required = ["sku", "name", "price", "stock"]
    for k in required:
        if k not in data:
            return _response(400, {"error": f"Missing field: {k}"})
    item = _normalize_item_numbers(data)
    tbl = table(ITEMS_TABLE)
    tbl.put_item(Item=item, ConditionExpression="attribute_not_exists(sku)")
    return _response(201, item)

def update_item(sku: str, data: dict):
    allowed = {"name", "price", "stock"}
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return _response(400, {"error": "Nothing to update"})
    updates = _normalize_item_numbers(updates)
    expr = "SET " + ", ".join([f"#{k} = :{k}" for k in updates])
    names = {f"#{k}": k for k in updates}
    values = {f":{k}": updates[k] for k in updates}
    tbl = table(ITEMS_TABLE)
    resp = tbl.update_item(
        Key={"sku": sku},
        UpdateExpression=expr,
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
        ReturnValues="ALL_NEW"
    )
    return _response(200, resp["Attributes"])

def delete_item(sku: str):
    tbl = table(ITEMS_TABLE)
    tbl.delete_item(Key={"sku": sku})
    return _response(204, {})
