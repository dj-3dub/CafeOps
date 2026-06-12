# CafeOps

CafeOps is a serverless operations platform built to demonstrate modern cloud engineering practices using AWS services, Infrastructure as Code, and automated deployment workflows.

The platform manages inventory, stock movements, and order processing through a REST API backed by AWS Lambda, API Gateway, and DynamoDB. Infrastructure is provisioned and maintained using Terraform, while LocalStack provides a fully local development environment that mirrors core AWS services.

This project was designed to showcase practical cloud engineering skills including Infrastructure as Code, serverless application development, API design, automated provisioning, operational automation, and cloud-native architecture patterns.

## Architecture

### Core Components

* AWS Lambda for serverless business logic
* Amazon API Gateway for REST API exposure
* Amazon DynamoDB for inventory and order data
* Terraform for Infrastructure as Code
* LocalStack for local AWS service emulation
* Docker Compose for environment orchestration
* Makefile for operational automation

### Functional Areas

#### Inventory Management

Maintains product catalog information and inventory records.

#### Stock Movement Tracking

Tracks inventory adjustments, receipts, and stock changes.

#### Order Processing

Processes and records customer orders through REST API endpoints.

## Technology Stack

### Cloud Services

* AWS Lambda
* Amazon API Gateway
* Amazon DynamoDB

### Infrastructure

* Terraform
* Docker
* Docker Compose
* LocalStack

### Development

* Python 3.11
* REST APIs
* JSON

### Automation

* Makefile
* Shell scripting

## Repository Structure

```text
.
├── infra/
│   └── terraform/
├── scripts/
├── src/
│   ├── common/
│   └── handlers/
├── webui/
├── docker-compose.yml
├── Makefile
└── README.md
```

## Infrastructure as Code

Infrastructure is provisioned through Terraform and includes:

* DynamoDB tables
* IAM roles and policies
* Lambda functions
* API Gateway resources
* API deployments and stages

Terraform configuration is organized using:

* versions.tf
* providers.tf
* variables.tf
* outputs.tf
* main.tf

## Operations

### Start Environment

```bash
make up
```

### Validate Terraform

```bash
make tf-validate
```

### Apply Infrastructure

```bash
make tf-apply
```

### Run Smoke Tests

```bash
make smoke
```

### View Service Status

```bash
make status
```

## Skills Demonstrated

* Infrastructure as Code (Terraform)
* Serverless Architecture
* AWS Service Integration
* API Design and Development
* Cloud Resource Provisioning
* IAM and Access Management
* DynamoDB Data Modeling
* Docker-Based Development Environments
* Operational Automation
* Platform Engineering Fundamentals

## Future Enhancements

* CI/CD pipeline integration
* Automated testing workflows
* CloudWatch-style observability
* Authentication and authorization
* Multi-environment Terraform deployments
* Infrastructure security scanning

## License

This project is licensed under the terms of the LICENSE file included in this repository.
