# CafeOps - Operational Makefile

SHELL := /bin/bash

COMPOSE := docker compose
TF_DIR := infra/terraform
ARCH_DOT := cafeops_architecture_public.dot
ARCH_SVG := cafeops_architecture_public.svg
ARCH_PNG := cafeops_architecture_public.png

.PHONY: help up down restart logs status \
	tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy \
	smoke seed diag arch clean

help:
	@echo "CafeOps Commands"
	@echo ""
	@echo "  make up            Start LocalStack and supporting services"
	@echo "  make down          Stop services"
	@echo "  make restart       Restart services"
	@echo "  make logs          Follow service logs"
	@echo "  make status        Show service status"
	@echo ""
	@echo "  make tf-init       Initialize Terraform"
	@echo "  make tf-fmt        Format Terraform files"
	@echo "  make tf-validate   Validate Terraform configuration"
	@echo "  make tf-plan       Preview Terraform changes"
	@echo "  make tf-apply      Apply Terraform infrastructure"
	@echo "  make tf-destroy    Destroy Terraform infrastructure"
	@echo ""
	@echo "  make seed          Seed sample data"
	@echo "  make smoke         Run smoke tests"
	@echo "  make diag          Run basic diagnostics"
	@echo "  make arch          Render architecture diagram"
	@echo "  make clean         Remove generated local artifacts"

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f

status:
	$(COMPOSE) ps

tf-init:
	cd $(TF_DIR) && terraform init

tf-fmt:
	cd $(TF_DIR) && terraform fmt -recursive

tf-validate:
	cd $(TF_DIR) && terraform validate

tf-plan:
	cd $(TF_DIR) && terraform plan

tf-apply:
	cd $(TF_DIR) && terraform apply -auto-approve

tf-destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

seed:
	python3 scripts/seed.py

smoke:
	bash scripts/smoke.sh

diag:
	@echo "Docker services:"
	@$(COMPOSE) ps
	@echo ""
	@echo "Terraform files:"
	@find $(TF_DIR) -maxdepth 1 -type f -print
	@echo ""
	@echo "Project scripts:"
	@find scripts -maxdepth 1 -type f -print

arch:
	dot -Tsvg $(ARCH_DOT) -o $(ARCH_SVG)
	dot -Tpng $(ARCH_DOT) -o $(ARCH_PNG)
	@echo "Wrote $(ARCH_SVG) and $(ARCH_PNG)"

clean:
	rm -f $(ARCH_SVG) $(ARCH_PNG)
	rm -f infra/terraform/terraform_api_url.txt infra/terraform_api_url.txt
	rm -rf .terraform
	@echo "Cleaned generated local artifacts"
