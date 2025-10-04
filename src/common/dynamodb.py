import os
import json
import boto3
from decimal import Decimal, ROUND_DOWN

REGION = os.environ.get("AWS_REGION", "us-east-1")

endpoint = os.environ.get("ENDPOINT_URL")
if not endpoint:
    host = os.environ.get("LOCALSTACK_HOSTNAME")
    if host:
        endpoint = f"http://{host}:4566"

_session = boto3.session.Session(region_name=REGION)
if endpoint:
    _dynamodb = _session.resource("dynamodb", endpoint_url=endpoint)
    client = _session.client("dynamodb", endpoint_url=endpoint)
else:
    _dynamodb = _session.resource("dynamodb")
    client = _session.client("dynamodb")

def table(name: str):
    return _dynamodb.Table(name)

def _json_default(x):
    if isinstance(x, Decimal):
        # if it's an integer value, return int; otherwise float for readability
        if x == x.to_integral_value(rounding=ROUND_DOWN):
            return int(x)
        return float(x)
    raise TypeError(f"Object of type {type(x).__name__} is not JSON serializable")

def json_dumps(o) -> str:
    return json.dumps(o, default=_json_default)
