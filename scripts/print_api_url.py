import sys, json, os
data = json.load(sys.stdin)
url = data.get("api_endpoint", {}).get("value")
print(url)
out = os.path.join(os.path.dirname(__file__), "..", "infra", "terraform_api_url.txt")
with open(out, "w") as f:
    f.write(url)

