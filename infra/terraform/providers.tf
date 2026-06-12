provider "aws" {
  region                      = var.aws_region
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
