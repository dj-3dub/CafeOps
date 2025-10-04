terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "lambda_zip_dir" { type = string }
variable "endpoint_url" { type = string }

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway = var.endpoint_url
    dynamodb   = var.endpoint_url
    iam        = var.endpoint_url
    lambda     = var.endpoint_url
    logs       = var.endpoint_url
    sts        = var.endpoint_url
    cloudwatch = var.endpoint_url
  }
}

# ---------------- DynamoDB ----------------
resource "aws_dynamodb_table" "items" {
  name         = "Items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sku"

  attribute {
    name = "sku"
    type = "S"
  }
}

resource "aws_dynamodb_table" "orders" {
  name         = "Orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "movements" {
  name         = "StockMovements"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------- IAM for Lambdas ----------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "inventory-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda_perm" {
  statement {
    actions   = ["dynamodb:*", "logs:*", "cloudwatch:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "inventory-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_perm.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ---------------- Package Lambdas ----------------
data "archive_file" "items_zip" {
  type        = "zip"
  source_dir  = var.lambda_zip_dir
  output_path = "${path.module}/items.zip"
  excludes    = ["handlers/orders.py", "handlers/stock.py"]
}

data "archive_file" "orders_zip" {
  type        = "zip"
  source_dir  = var.lambda_zip_dir
  output_path = "${path.module}/orders.zip"
  excludes    = ["handlers/items.py", "handlers/stock.py"]
}

data "archive_file" "stock_zip" {
  type        = "zip"
  source_dir  = var.lambda_zip_dir
  output_path = "${path.module}/stock.zip"
  excludes    = ["handlers/items.py", "handlers/orders.py"]
}

# ---------------- Lambda functions ----------------
resource "aws_lambda_function" "items" {
  function_name    = "items"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "handlers.items.handler"
  filename         = data.archive_file.items_zip.output_path
  source_code_hash = data.archive_file.items_zip.output_base64sha256

  environment {
    variables = {
      ITEMS_TABLE           = aws_dynamodb_table.items.name
      ENDPOINT_URL = "http://localstack:4566"
      AWS_REGION            = "us-east-1"
      AWS_ACCESS_KEY_ID     = "test"
      AWS_SECRET_ACCESS_KEY = "test"
      DEBUG = "0"
      DEBUG = "0"
      DEBUG = "0"
    }
  }
}

resource "aws_lambda_function" "orders" {
  function_name    = "orders"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "handlers.orders.handler"
  filename         = data.archive_file.orders_zip.output_path
  source_code_hash = data.archive_file.orders_zip.output_base64sha256

  environment {
    variables = {
      ITEMS_TABLE           = aws_dynamodb_table.items.name
      ORDERS_TABLE          = aws_dynamodb_table.orders.name
      ENDPOINT_URL = "http://localstack:4566"
      AWS_REGION            = "us-east-1"
      AWS_ACCESS_KEY_ID     = "test"
      AWS_SECRET_ACCESS_KEY = "test"
      DEBUG = "0"
    }
  }
}

resource "aws_lambda_function" "stock" {
  function_name    = "stock"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "handlers.stock.handler"
  filename         = data.archive_file.stock_zip.output_path
  source_code_hash = data.archive_file.stock_zip.output_base64sha256

  environment {
    variables = {
      ITEMS_TABLE           = aws_dynamodb_table.items.name
      MOVES_TABLE           = aws_dynamodb_table.movements.name
      ENDPOINT_URL = "http://localstack:4566"
      AWS_REGION            = "us-east-1"
      AWS_ACCESS_KEY_ID     = "test"
      AWS_SECRET_ACCESS_KEY = "test"
      DEBUG = "0"
    }
  }
}

# ---------------- API Gateway v1 (REST API) ----------------
resource "aws_api_gateway_rest_api" "api" {
  name = "inventory-api"
}

# /items and /items/{proxy+} -> items lambda
resource "aws_api_gateway_resource" "items_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "items"
}

resource "aws_api_gateway_method" "items_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items_root.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "items_root" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items_root.id
  http_method             = aws_api_gateway_method.items_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.items.invoke_arn
}

resource "aws_api_gateway_resource" "items_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.items_root.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "items_proxy_any" {
  rest_api_id        = aws_api_gateway_rest_api.api.id
  resource_id        = aws_api_gateway_resource.items_proxy.id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "items_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items_proxy.id
  http_method             = aws_api_gateway_method.items_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.items.invoke_arn
}

# /orders and /orders/{proxy+} -> orders lambda
resource "aws_api_gateway_resource" "orders_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "orders_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.orders_root.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "orders_root" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.orders_root.id
  http_method             = aws_api_gateway_method.orders_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.orders.invoke_arn
}

resource "aws_api_gateway_resource" "orders_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.orders_root.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "orders_proxy_any" {
  rest_api_id        = aws_api_gateway_rest_api.api.id
  resource_id        = aws_api_gateway_resource.orders_proxy.id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "orders_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.orders_proxy.id
  http_method             = aws_api_gateway_method.orders_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.orders.invoke_arn
}

# /stock and /stock/{proxy+} -> stock lambda
resource "aws_api_gateway_resource" "stock_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "stock"
}

resource "aws_api_gateway_method" "stock_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.stock_root.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "stock_root" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.stock_root.id
  http_method             = aws_api_gateway_method.stock_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.stock.invoke_arn
}

resource "aws_api_gateway_resource" "stock_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.stock_root.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "stock_proxy_any" {
  rest_api_id        = aws_api_gateway_rest_api.api.id
  resource_id        = aws_api_gateway_resource.stock_proxy.id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "stock_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.stock_proxy.id
  http_method             = aws_api_gateway_method.stock_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.stock.invoke_arn
}

# Permissions for API Gateway to invoke Lambdas
resource "aws_lambda_permission" "apig_items" {
  statement_id  = "AllowAPIGItems"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.items.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "apig_orders" {
  statement_id  = "AllowAPIGOrders"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orders.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "apig_stock" {
  statement_id  = "AllowAPIGStock"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stock.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

# Deployment + Stage
resource "aws_api_gateway_deployment" "deploy" {
  description = "redeploy-${timestamp()}"

  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.items_root,
    aws_api_gateway_integration.items_proxy,
    aws_api_gateway_integration.orders_root,
    aws_api_gateway_integration.orders_proxy,
    aws_api_gateway_integration.stock_root,
    aws_api_gateway_integration.stock_proxy
  ]
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  stage_name    = "dev"
}

# Output a LocalStack-friendly base URL for REST API
output "api_endpoint" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/${aws_api_gateway_stage.stage.stage_name}/_user_request_"
}

# ---------------- CORS (REST API) ----------------
# Helper locals for the three standard headers
locals {
  cors_method_response_params = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
  cors_integration_response_params = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,PATCH,OPTIONS'"
  }
}

# ITEMS ROOT: OPTIONS
resource "aws_api_gateway_method" "items_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items_root.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "items_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items_root.id
  http_method = aws_api_gateway_method.items_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}
resource "aws_api_gateway_method_response" "items_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items_root.id
  http_method = aws_api_gateway_method.items_options.http_method
  status_code = "200"
  response_parameters = local.cors_method_response_params
}
resource "aws_api_gateway_integration_response" "items_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items_root.id
  http_method = aws_api_gateway_method.items_options.http_method
  status_code = aws_api_gateway_method_response.items_options_200.status_code
  response_parameters = local.cors_integration_response_params
  depends_on = [aws_api_gateway_integration.items_options]
}

# ITEMS PROXY: OPTIONS
resource "aws_api_gateway_method" "items_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "items_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items_proxy.id
  http_method = aws_api_gateway_method.items_proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}
resource "aws_api_gateway_method_response" "items_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items_proxy.id
  http_method = aws_api_gateway_method.items_proxy_options.http_method
  status_code = "200"
  response_parameters = local.cors_method_response_params
}
resource "aws_api_gateway_integration_response" "items_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items_proxy.id
  http_method = aws_api_gateway_method.items_proxy_options.http_method
  status_code = aws_api_gateway_method_response.items_proxy_options_200.status_code
  response_parameters = local.cors_integration_response_params
  depends_on = [aws_api_gateway_integration.items_proxy_options]
}

# ORDERS ROOT: OPTIONS
resource "aws_api_gateway_method" "orders_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.orders_root.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "orders_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.orders_root.id
  http_method = aws_api_gateway_method.orders_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}
resource "aws_api_gateway_method_response" "orders_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.orders_root.id
  http_method = aws_api_gateway_method.orders_options.http_method
  status_code = "200"
  response_parameters = local.cors_method_response_params
}
resource "aws_api_gateway_integration_response" "orders_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.orders_root.id
  http_method = aws_api_gateway_method.orders_options.http_method
  status_code = aws_api_gateway_method_response.orders_options_200.status_code
  response_parameters = local.cors_integration_response_params
  depends_on = [aws_api_gateway_integration.orders_options]
}

# ORDERS PROXY: OPTIONS
resource "aws_api_gateway_method" "orders_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.orders_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "orders_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.orders_proxy.id
  http_method = aws_api_gateway_method.orders_proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}
resource "aws_api_gateway_method_response" "orders_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.orders_proxy.id
  http_method = aws_api_gateway_method.orders_proxy_options.http_method
  status_code = "200"
  response_parameters = local.cors_method_response_params
}
resource "aws_api_gateway_integration_response" "orders_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.orders_proxy.id
  http_method = aws_api_gateway_method.orders_proxy_options.http_method
  status_code = aws_api_gateway_method_response.orders_proxy_options_200.status_code
  response_parameters = local.cors_integration_response_params
  depends_on = [aws_api_gateway_integration.orders_proxy_options]
}

# STOCK ROOT: OPTIONS
resource "aws_api_gateway_method" "stock_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.stock_root.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "stock_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.stock_root.id
  http_method = aws_api_gateway_method.stock_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}
resource "aws_api_gateway_method_response" "stock_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.stock_root.id
  http_method = aws_api_gateway_method.stock_options.http_method
  status_code = "200"
  response_parameters = local.cors_method_response_params
}
resource "aws_api_gateway_integration_response" "stock_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.stock_root.id
  http_method = aws_api_gateway_method.stock_options.http_method
  status_code = aws_api_gateway_method_response.stock_options_200.status_code
  response_parameters = local.cors_integration_response_params
  depends_on = [aws_api_gateway_integration.stock_options]
}

# STOCK PROXY: OPTIONS
resource "aws_api_gateway_method" "stock_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.stock_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "stock_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.stock_proxy.id
  http_method = aws_api_gateway_method.stock_proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}
resource "aws_api_gateway_method_response" "stock_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.stock_proxy.id
  http_method = aws_api_gateway_method.stock_proxy_options.http_method
  status_code = "200"
  response_parameters = local.cors_method_response_params
}
resource "aws_api_gateway_integration_response" "stock_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.stock_proxy.id
  http_method = aws_api_gateway_method.stock_proxy_options.http_method
  status_code = aws_api_gateway_method_response.stock_proxy_options_200.status_code
  response_parameters = local.cors_integration_response_params
  depends_on = [aws_api_gateway_integration.stock_proxy_options]
}
