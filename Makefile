# ============================================================
# CafeOps - Operational Makefile
# Design. Deploy. Validate. Automate.
# ============================================================

SHELL := /bin/bash

COMPOSE := docker compose
TF_DIR := infra/terraform

ARCH_DIR := docs/architecture
ARCH_DOT := $(ARCH_DIR)/cafeops.dot
ARCH_SVG := $(ARCH_DIR)/cafeops.svg
ARCH_PNG := $(ARCH_DIR)/cafeops.png

.PHONY: help \
	doctor \
	up down restart status logs \
	init fmt validate plan apply destroy deploy \
	tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy \
	seed smoke test diag arch docs clean prune

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

help:
	@echo ""
	@echo "CafeOps Commands"
	@echo "Design. Deploy. Validate. Automate."
	@echo ""
	@echo "Health"
	@echo "  make doctor         Check local development dependencies"
	@echo ""
	@echo "Lifecycle"
	@echo "  make up             Start LocalStack and supporting services"
	@echo "  make down           Stop services"
	@echo "  make restart        Restart services"
	@echo "  make status         Show service status"
	@echo "  make logs           Follow service logs"
	@echo ""
	@echo "Infrastructure"
	@echo "  make init           Initialize Terraform"
	@echo "  make fmt            Format Terraform files"
	@echo "  make validate       Initialize, format, and validate Terraform"
	@echo "  make plan           Preview Terraform changes"
	@echo "  make apply          Apply Terraform infrastructure"
	@echo "  make deploy         Full local deploy: up, init, apply, seed, smoke"
	@echo "  make destroy        Destroy Terraform infrastructure"
	@echo ""
	@echo "Application"
	@echo "  make seed           Seed sample data"
	@echo "  make smoke          Run smoke tests"
	@echo "  make test           Run project tests"
	@echo ""
	@echo "Operations"
	@echo "  make diag           Run diagnostics"
	@echo ""
	@echo "Documentation"
	@echo "  make arch           Render architecture diagrams"
	@echo "  make docs           Show documentation files"
	@echo ""
	@echo "Cleanup"
	@echo "  make clean          Remove generated local artifacts"
	@echo "  make prune          Stop services and clean local artifacts"
	@echo ""

# ------------------------------------------------------------
# Health
# ------------------------------------------------------------

doctor:
	@echo ""
	@echo "CafeOps Doctor"
	@echo "=============="
	@echo ""
	@command -v docker >/dev/null 2>&1 && echo "✓ Docker installed" || echo "✗ Docker missing"
	@docker info >/dev/null 2>&1 && echo "✓ Docker daemon running" || echo "✗ Docker daemon not running"
	@command -v terraform >/dev/null 2>&1 && echo "✓ Terraform installed" || echo "✗ Terraform missing"
	@command -v python3 >/dev/null 2>&1 && echo "✓ Python 3 installed" || echo "✗ Python 3 missing"
	@command -v make >/dev/null 2>&1 && echo "✓ Make installed" || echo "✗ Make missing"
	@command -v git >/dev/null 2>&1 && echo "✓ Git installed" || echo "✗ Git missing"
	@command -v dot >/dev/null 2>&1 && echo "✓ Graphviz installed" || echo "⚠ Graphviz missing"
	@echo ""

# ------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart: down up

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

# ------------------------------------------------------------
# Infrastructure
# ------------------------------------------------------------

init:
	cd $(TF_DIR) && terraform init

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate: init fmt
	cd $(TF_DIR) && terraform validate

plan:
	cd $(TF_DIR) && terraform plan

apply:
	cd $(TF_DIR) && terraform apply -auto-approve

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

deploy: up init apply seed smoke
	@echo ""
	@echo "CafeOps deployment complete"
	@echo "Run 'make validate' to verify the environment"
	@echo ""

# Backward-compatible aliases
tf-init: init
tf-fmt: fmt
tf-validate: validate
tf-plan: plan
tf-apply: apply
tf-destroy: destroy

# ------------------------------------------------------------
# Application
# ------------------------------------------------------------

seed:
	python3 scripts/seed.py

smoke:
	bash scripts/smoke.sh

test: smoke

# ------------------------------------------------------------
# Operations
# ------------------------------------------------------------

diag:
	@echo ""
	@echo "CafeOps Diagnostics"
	@echo "==================="
	@echo ""
	@echo "Docker services:"
	@$(COMPOSE) ps
	@echo ""
	@echo "Terraform files:"
	@find $(TF_DIR) -maxdepth 1 -type f -print | sort
	@echo ""
	@echo "Project scripts:"
	@find scripts -maxdepth 1 -type f -print | sort
	@echo ""

# ------------------------------------------------------------
# Documentation
# ------------------------------------------------------------

arch:
	@mkdir -p $(ARCH_DIR)
	dot -Tsvg $(ARCH_DOT) -o $(ARCH_SVG)
	dot -Tpng $(ARCH_DOT) -o $(ARCH_PNG)
	@echo "Wrote $(ARCH_SVG)"
	@echo "Wrote $(ARCH_PNG)"

docs:
	@echo ""
	@echo "CafeOps Documentation"
	@echo "====================="
	@find docs -maxdepth 2 -type f | sort
	@echo ""

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

clean:
	rm -f infra/terraform/terraform_api_url.txt
	rm -f infra/terraform_api_url.txt
	rm -f webui/config.js
	rm -rf $(TF_DIR)/.terraform
	rm -rf .localstack
	rm -rf __pycache__
	rm -rf src/**/__pycache__
	rm -rf scripts/**/__pycache__
	@echo "Cleaned generated local artifacts"

prune: down clean
