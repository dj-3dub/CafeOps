SHELL := /bin/bash
AWS_REGION ?= us-east-1
AWS_ACCESS_KEY_ID ?= test
AWS_SECRET_ACCESS_KEY ?= test
ENDPOINT_URL ?= http://localhost:4566

export AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

.PHONY: up down init plan apply destroy seed outputs curl-items curl-new-order url

up:
	docker compose up -d

down:
	docker compose down -v

init:
	cd infra/terraform && terraform init

plan:
	cd infra/terraform && terraform plan -var="lambda_zip_dir=../../src" -var="endpoint_url=$(ENDPOINT_URL)"

apply:
	cd infra/terraform && terraform apply -auto-approve -var="lambda_zip_dir=../../src" -var="endpoint_url=$(ENDPOINT_URL)"

destroy:
	cd infra/terraform && terraform destroy -auto-approve -var="lambda_zip_dir=../../src" -var="endpoint_url=$(ENDPOINT_URL)"

seed:
	python3 scripts/seed.py

outputs:
	cd infra/terraform && terraform output -json | python3 ../../scripts/print_api_url.py

url: outputs

curl-items:
	bash scripts/curl_examples.sh list_items

curl-new-order:
	bash scripts/curl_examples.sh new_order
