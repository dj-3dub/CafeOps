# CafeOps Runbook

## Environment Startup

Start LocalStack and supporting services:

```bash
make up
```

Verify services:

```bash
make status
```

View logs:

```bash
make logs
```

## Terraform Operations

Initialize Terraform:

```bash
make tf-init
```

Format configuration:

```bash
make tf-fmt
```

Validate configuration:

```bash
make tf-validate
```

Preview changes:

```bash
make tf-plan
```

Deploy infrastructure:

```bash
make tf-apply
```

Destroy infrastructure:

```bash
make tf-destroy
```

## Data Seeding

Populate sample data:

```bash
make seed
```

## Smoke Testing

Run validation tests:

```bash
make smoke
```

## Troubleshooting

### Terraform Validation Failure

```bash
terraform init
terraform validate
```

### LocalStack Not Running

```bash
docker compose ps
docker compose logs
```

### API Not Responding

Verify:

* LocalStack is running
* Terraform applied successfully
* API endpoint exists
* Lambda functions deployed

## Environment Shutdown

```bash
make down
```
