from common.dynamodb import table, json_dumps
import json, uuid, os, time
from decimal import Decimal

ITEMS_TABLE = os.environ.get("ITEMS_TABLE", "Items")
ORDERS_TABLE = os.environ.get("ORDERS_TABLE", "Orders")

CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PATCH,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,Authorization"
}

def _response(status, body):
    headers = {"Content-Type": "application/json", **CORS}
    return {"statusCode": status, "headers": headers, "body": json_dumps(body)}

def _normalize(event):
    rc = event.get("requestContext", {})
    body = event.get("body")
    if isinstance(rc, dict) and rc.get("http"):  # v2
        method = rc["http"].get("method")
        path = event.get("rawPath") or event.get("path", "")
        return method, path, body
    # v1 with stage
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

    if path == "/orders":
        if method == "GET":
            return list_orders()
        if method == "POST":
            data = json.loads(body or "{}")
            return create_order(data)

    if path.startswith("/orders/"):
        oid = path.split("/orders/")[1]
        if method == "GET":
            return get_order(oid)
        if method == "PATCH":
            data = json.loads(body or "{}")
            return patch_order(oid, data)

    return _response(404, {"error": "Not found"})

def list_orders():
    tbl = table(ORDERS_TABLE)
    resp = tbl.scan(Limit=100)
    return _response(200, resp.get("Items", []))

def get_order(order_id: str):
    tbl = table(ORDERS_TABLE)
    resp = tbl.get_item(Key={"id": order_id})
    if "Item" not in resp:
        return _response(404, {"error": "Order not found"})
    return _response(200, resp["Item"])

def create_order(data: dict):
    items = data.get("items", [])
    if not items:
        return _response(400, {"error": "No items in order"})
    items_tbl = table(ITEMS_TABLE)
    for line in items:
        sku = line.get("sku"); qty = int(line.get("qty", 0))
        if not sku or qty <= 0:
            return _response(400, {"error": f"Invalid line: {line}"})
        items_tbl.update_item(
            Key={"sku": sku},
            UpdateExpression="SET stock = stock - :dec",
            ConditionExpression="attribute_exists(sku) AND stock >= :dec",
            ExpressionAttributeValues={":dec": qty},
            ReturnValues="NONE"
        )
    order = {
        "id": str(uuid.uuid4()),
        "status": "PLACED",
        "items": items,
        "created": int(time.time())
    }
    orders_tbl = table(ORDERS_TABLE)
    orders_tbl.put_item(Item=order)
    return _response(201, order)

def patch_order(order_id: str, data: dict):
    allowed = {"status"}
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return _response(400, {"error": "Nothing to update"})
    expr = "SET " + ", ".join([f"#{k} = :{k}" for k in updates])
    names = {f"#{k}": k for k in updates}
    values = {f":{k}": updates[k] for k in updates}
    tbl = table(ORDERS_TABLE)
    resp = tbl.update_item(
        Key={"id": order_id},
        UpdateExpression=expr,
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
        ReturnValues="ALL_NEW"
    )
    return _response(200, resp["Attributes"])
