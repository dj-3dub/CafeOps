import os, json, requests

api_url_file = os.path.join(os.path.dirname(__file__), "..", "infra", "terraform_api_url.txt")
if os.path.exists(api_url_file):
    with open(api_url_file, "r") as f:
        API = f.read().strip()
else:
    API = input("Enter API base URL (e.g., https://<id>.execute-api.localhost.localstack.cloud:4566): ").strip()

items = [
    {"sku": "ESP-001", "name": "Espresso", "price": 3.50, "stock": 20},
    {"sku": "LAT-001", "name": "Latte", "price": 4.75, "stock": 15},
    {"sku": "CAP-001", "name": "Cappuccino", "price": 4.25, "stock": 12},
]

for it in items:
    r = requests.post(API + "/items", json=it)
    print("POST /items", r.status_code, r.text)
