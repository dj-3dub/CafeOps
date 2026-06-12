variable "lambda_zip_dir" {
  description = "Path to the Lambda source directory that Terraform packages into deployment zip files."
  type        = string
}

variable "endpoint_url" {
  description = "LocalStack endpoint URL used by Terraform and Lambda functions during local development."
  type        = string
  default     = "http://localhost:4566"
}

variable "lambda_endpoint_url" {
  description = "LocalStack endpoint URL used inside Lambda containers."
  type        = string
  default     = "http://localstack:4566"
}

variable "aws_region" {
  description = "AWS region used for local emulation."
  type        = string
  default     = "us-east-1"
}
