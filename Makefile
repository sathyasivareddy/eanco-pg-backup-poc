# Eanco PostgreSQL Backup POC — developer/operator convenience targets.
# These wrap local validation and safe read-only operations.
# No target runs `terraform apply` or creates Azure resources non-interactively.

SHELL := /bin/bash
TF ?= terraform
STATE1 := terraform/01-postgresql-foundation
STATE2 := terraform/02-postgresql-backup-solution
IMAGE ?= eanco-pg-backup
IMAGE_TAG ?= local

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

## ---- Terraform ----
.PHONY: fmt
fmt: ## terraform fmt -recursive
	$(TF) fmt -recursive

.PHONY: fmt-check
fmt-check: ## terraform fmt check (CI)
	$(TF) fmt -recursive -check

.PHONY: init
init: ## terraform init (backend disabled) for both roots
	cd $(STATE1) && $(TF) init -backend=false
	cd $(STATE2) && $(TF) init -backend=false

.PHONY: validate
validate: ## terraform validate for both roots
	cd $(STATE1) && $(TF) init -backend=false >/dev/null && $(TF) validate
	cd $(STATE2) && $(TF) init -backend=false >/dev/null && $(TF) validate

.PHONY: lint
lint: ## tflint + shellcheck
	command -v tflint >/dev/null && (cd $(STATE1) && tflint) || echo "tflint not installed"
	command -v tflint >/dev/null && (cd $(STATE2) && tflint) || echo "tflint not installed"
	command -v shellcheck >/dev/null && shellcheck src/*.sh scripts/*.sh src/tests/*.sh || echo "shellcheck not installed"

.PHONY: security
security: ## checkov/tfsec + trivy filesystem scan
	command -v checkov >/dev/null && checkov -d $(STATE1) --quiet || echo "checkov not installed (State 1)"
	command -v checkov >/dev/null && checkov -d $(STATE2) --quiet || echo "checkov not installed (State 2)"
	command -v trivy >/dev/null && trivy fs --scanners vuln,secret,misconfig . || echo "trivy not installed"

.PHONY: test
test: ## run shell unit tests
	bash src/tests/test-input-validation.sh
	bash src/tests/test-backup-script.sh
	bash src/tests/test-blob-path.sh
	bash src/tests/test-error-handling.sh

## ---- Container ----
.PHONY: docker-build
docker-build: ## build the backup image locally
	docker build -t $(IMAGE):$(IMAGE_TAG) src/

.PHONY: docker-scan
docker-scan: ## scan the built image with trivy
	command -v trivy >/dev/null && trivy image $(IMAGE):$(IMAGE_TAG) || echo "trivy not installed"

## ---- Aggregate ----
.PHONY: check
check: fmt-check validate lint security test ## run all local checks
