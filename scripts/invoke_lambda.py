#!/usr/bin/env python3
import json, boto3, os, sys

REGION = os.environ.get("AWS_REGION", "us-east-1")
ENDPOINT = os.environ.get("ENDPOINT_URL", "http://localhost:4566")
fn = sys.argv[1] if len(sys.argv) > 1 else "items"

print(f"Invoking Lambda '{fn}' via {ENDPOINT} in {REGION}")

cli = boto3.client("lambda", region_name=REGION, endpoint_url=ENDPOINT)

def invoke(event, label):
    resp = cli.invoke(FunctionName=fn, Payload=json.dumps(event).encode())
    payload = resp["Payload"].read().decode()
    print(f"\n--- {label} ---")
    print("StatusCode:", resp.get("StatusCode"), "FunctionError:", resp.get("FunctionError"))
    print(payload)

# Emulate API Gateway REST (v1) event hitting GET /items on stage 'dev'
event_v1 = {
    "resource": "/items",
    "path": "/dev/items",
    "httpMethod": "GET",
    "headers": {},
    "multiValueHeaders": {},
    "queryStringParameters": None,
    "multiValueQueryStringParameters": None,
    "pathParameters": None,
    "stageVariables": None,
    "requestContext": {"stage": "dev"},
    "body": None,
    "isBase64Encoded": False,
}

# Emulate HTTP API (v2), just in case
event_v2 = {
    "version": "2.0",
    "routeKey": "GET /items",
    "rawPath": "/items",
    "rawQueryString": "",
    "requestContext": {"http": {"method": "GET", "path": "/items"}},
    "headers": {},
    "isBase64Encoded": False,
}

invoke(event_v1, "REST v1 /dev/items")
invoke(event_v2, "HTTP v2 /items")
