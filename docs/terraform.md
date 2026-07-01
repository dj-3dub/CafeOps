# Terraform Design

## Purpose

Terraform manages the complete CafeOps infrastructure stack.

## File Layout

```text
infra/terraform/
├── versions.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── main.tf
```

## Components

### DynamoDB

* Items
* Orders
* StockMovements

### IAM

* Lambda execution role
* Policy attachments

### Lambda

* items
* orders
* stock

### API Gateway

* REST API
* Resource routing
* Stage deployment
* CORS configuration

## LocalStack Integration

Terraform is configured to deploy resources into LocalStack rather than a live AWS account.

This allows local development, testing, and validation without incurring AWS costs.

## Deployment Workflow

```bash
make tf-init
make tf-plan
make tf-apply
```

## Validation

```bash
make tf-fmt
make tf-validate
```
