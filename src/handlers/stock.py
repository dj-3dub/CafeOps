from common.dynamodb import table, json_dumps
import json, time, os, uuid
from decimal import Decimal

ITEMS_TABLE = os.environ.get("ITEMS_TABLE", "Items")
MOVES_TABLE = os.environ.get("MOVES_TABLE", "StockMovements")

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

    if path == "/stock/in" and method == "POST":
        data = json.loads(body or "{}")
        return stock_in(data)
    if path == "/stock/out" and method == "POST":
        data = json.loads(body or "{}")
        return stock_out(data)

    return _response(404, {"error": "Not found"})

def stock_in(data: dict):
    sku = data.get("sku"); qty = int(data.get("qty", 0)); reason = data.get("reason", "adjustment")
    if not sku or qty <= 0:
        return _response(400, {"error": "Invalid sku/qty"})
    items = table(ITEMS_TABLE)
    resp = items.update_item(
        Key={"sku": sku},
        UpdateExpression="SET stock = if_not_exists(stock, :z) + :inc",
        ExpressionAttributeValues={":inc": qty, ":z": 0},
        ReturnValues="ALL_NEW"
    )
    moves = table(MOVES_TABLE)
    movement = {"id": str(uuid.uuid4()), "sku": sku, "qty": qty, "type": "IN", "ts": int(time.time()), "reason": reason}
    moves.put_item(Item=movement)
    return _response(200, {"item": resp["Attributes"], "movement": movement})

def stock_out(data: dict):
    sku = data.get("sku"); qty = int(data.get("qty", 0)); reason = data.get("reason", "sale")
    if not sku or qty <= 0:
        return _response(400, {"error": "Invalid sku/qty"})
    items = table(ITEMS_TABLE)
    resp = items.update_item(
        Key={"sku": sku},
        UpdateExpression="SET stock = stock - :dec",
        ConditionExpression="attribute_exists(sku) AND stock >= :dec",
        ExpressionAttributeValues={":dec": qty},
        ReturnValues="ALL_NEW"
    )
    moves = table(MOVES_TABLE)
    movement = {"id": str(uuid.uuid4()), "sku": sku, "qty": qty, "type": "OUT", "ts": int(time.time()), "reason": reason}
    moves.put_item(Item=movement)
    return _response(200, {"item": resp["Attributes"], "movement": movement})
