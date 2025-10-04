import os, boto3

endpoint = os.environ.get("ENDPOINT_URL","http://localhost:4566")
region   = os.environ.get("AWS_REGION","us-east-1")

print("Using endpoint:", endpoint)
sess = boto3.session.Session(region_name=region)
dynamodb = sess.resource("dynamodb", endpoint_url=endpoint)

tables = list(dynamodb.tables.all())
print("Tables:", [t.name for t in tables])

items = dynamodb.Table("Items")
try:
    print("Scan Items ->", items.scan(Limit=5))
except Exception as e:
    print("Error scanning Items:", e)
