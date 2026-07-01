# CafeOps Architecture

## Overview

CafeOps is a serverless operations platform that demonstrates cloud-native application design using AWS services, Infrastructure as Code, and automated deployment workflows.

The platform provides REST API endpoints for inventory management, order processing, and stock movement tracking.

## Architecture Diagram

![Architecture](../cafeops_architecture_public.svg)

## Core Components

### API Gateway

Acts as the public entry point for all API requests.

Endpoints:

* `/items`
* `/orders`
* `/stock`

### AWS Lambda

Serverless compute layer providing business logic.

Functions:

* items
* orders
* stock

### DynamoDB

Data persistence layer.

Tables:

* Items
* Orders
* StockMovements

### Terraform

Infrastructure provisioning and lifecycle management.

Terraform provisions:

* API Gateway
* Lambda Functions
* IAM Roles and Policies
* DynamoDB Tables

### LocalStack

Provides local AWS service emulation for development and testing.

## Request Flow

1. Client submits API request.
2. API Gateway receives request.
3. Request is routed to Lambda.
4. Lambda executes business logic.
5. DynamoDB stores or retrieves data.
6. Response is returned to the client.

## Security

IAM roles provide least-privilege access for Lambda functions to DynamoDB and logging services.

## Operational Automation

Operational workflows are managed through Makefile targets and Terraform automation.
