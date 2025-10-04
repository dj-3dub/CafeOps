<p align="center">
  <img src="https://img.shields.io/badge/☕-CafeOps-brown?style=for-the-badge" alt="CafeOps Logo"/>
</p>

# ☕ CafeOps

**CafeOps** is a fully serverless **coffee shop inventory & order management system**, built on:

- **AWS Lambda** – serverless compute  
- **API Gateway (REST)** – routing & CORS  
- **DynamoDB** – Items, Orders, and StockMovements tables  
- **LocalStack** – local AWS emulation for fast, cost-free dev/test  

### 🌟 Features
- Manage coffee shop inventory (add, update, delete items)
- Track stock in/out movements
- Place and list orders
- WebUI with dropdown menus and cart
- Smoke tests + seed script for realistic cafe menu

### 🛠️ Stack
- Terraform (infra as code)
- Python (Lambda functions + scripts)
- LocalStack (local AWS emulation)
- React-lite frontend (vanilla React via CDN)

### 🚀 Quickstart
```bash
# 1. Clone & enter project
git clone <your-repo-url>
cd cafeops

# 2. Start LocalStack
docker compose up -d localstack

# 3. Deploy infrastructure
make init apply

# 4. Seed some cafe items
python3 scripts/seed_items.py

# 5. Serve the web UI
cd webui
python3 -m http.server 8082
