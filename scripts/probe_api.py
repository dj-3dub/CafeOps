import os, sys, json, urllib.request

api = (open("infra/terraform/terraform_api_url.txt").read().strip()
       if os.path.exists("infra/terraform/terraform_api_url.txt")
       else sys.argv[1] if len(sys.argv)>1 else "")
if not api:
    print("No API URL. Run: make outputs")
    sys.exit(1)

def call(path, data=None, method=None):
    url = api + path
    req = urllib.request.Request(url, method=method or ("POST" if data else "GET"))
    if data is not None:
        body = json.dumps(data).encode()
        req.add_header("Content-Type","application/json")
        req.data = body
    try:
        with urllib.request.urlopen(req) as r:
            print(method or ("POST" if data else "GET"), path, r.status)
            print(r.read().decode())
    except urllib.error.HTTPError as e:
        print(method or ("POST" if data else "GET"), path, e.code)
        print(e.read().decode())
    print("-"*60)

call("/items")
