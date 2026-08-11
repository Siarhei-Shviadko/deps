-include .env
-include Makefile.local

repository_url := ${REPOSITORY_URL}
project := ${PROJECT_NAME}
hash := $(shell git rev-parse --short=8 HEAD 2>/dev/null || echo "dev")
tag := $(shell git describe --tags --always 2>/dev/null || echo "latest")
date := $(shell date)

ALL_SUBMODULES := $(shell git config --file .gitmodules --get-regexp path | awk '{ print $$2 }')

GROUPS := core-services feature-services extraction-plugins
INFRA := core-services/deps-infra
LITELLM := core-services/deps-litellm

# started explicitly and in order, so they are skipped by the application loops
SKIP := $(INFRA) $(LITELLM) core-services/deps-ocr-gateway

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "DEPS — local orchestration"
	@echo ""
	@echo "One command to try it:"
	@echo "  make start              fetch + env + build + run everything"
	@echo ""
	@echo "Stages (each also runs on its own, in this order):"
	@echo "  make fetch              git submodule update --init --recursive, per group"
	@echo "  make env                create empty .env placeholders; seed litellm provider env"
	@echo "  make local-build        cd <service> && make build"
	@echo "  make local-run-infra    deps-infra, then deps-litellm"
	@echo "  make local-migrate      cd <service> && make migrate, where present"
	@echo "  make local-run          cd <service> && make run"
	@echo ""
	@echo "Operate:"
	@echo "  make status             show running containers"
	@echo "  make local-stop         stop all services"
	@echo "  make down               stop all services and remove volumes"
	@echo ""
	@echo "Per service (delegates to that submodule's Makefile):"
	@echo "  make build-<svc> run-<svc> migrate-<svc> logs-<svc> stop-<svc>"
	@echo "  e.g. make run-deps-backend, make logs-deps-frontend"

.PHONY: fetch-core-services
fetch-core-services:
	git submodule update --init --recursive core-services/

.PHONY: fetch-feature-services
fetch-feature-services:
	git submodule update --init --recursive feature-services/

.PHONY: fetch-extraction-plugins
fetch-extraction-plugins:
	git submodule update --init --recursive extraction-plugins/

.PHONY: fetch
fetch: | fetch-core-services fetch-feature-services fetch-extraction-plugins

.PHONY: env
env:
	test -f .env || cp .env.example .env

	# Several services list ./.env in their compose env_file; create an empty
	# placeholder in each service directory so compose does not error on a missing file.
	# Each service owns its own configuration via its tracked .dev.env.
	for group in $(GROUPS); do \
		for service in $$group/*; do \
			if [ -d "$$service" ]; then touch "$$service/.env"; fi; \
		done; \
	done

	# deps-litellm requires a second, nested env file for provider credentials;
	# seed it from the template on first run.
	test -f $(LITELLM)/etc/litellm/.env || cp $(LITELLM)/etc/litellm/.env.example $(LITELLM)/etc/litellm/.env

.PHONY: local-build
local-build:
	@echo "Building services..."

	for group in $(GROUPS); do \
		for service in $$group/*; do \
			case " $(SKIP) " in *" $$service "*) continue;; esac; \
			if [ -f "$$service/Makefile" ]; then (cd "$$service" && $(MAKE) build); fi; \
		done; \
	done

.PHONY: local-run-infra
local-run-infra:
	@echo "Running infrastructure..."

	cd $(INFRA) && $(MAKE) run
	cd $(LITELLM) && $(MAKE) run

.PHONY: local-migrate
local-migrate:
	@echo "Running migrations..."

	for group in $(GROUPS); do \
		for service in $$group/*; do \
			case " $(SKIP) " in *" $$service "*) continue;; esac; \
			if grep -qE '^migrate:' "$$service/Makefile" 2>/dev/null; then (cd "$$service" && $(MAKE) migrate); fi; \
		done; \
	done

.PHONY: local-run
local-run:
	@echo "Running services..."

	for group in $(GROUPS); do \
		for service in $$group/*; do \
			case " $(SKIP) " in *" $$service "*) continue;; esac; \
			if [ -f "$$service/Makefile" ]; then (cd "$$service" && $(MAKE) run); fi; \
		done; \
	done

.PHONY: local-stop
local-stop:
	@echo "Stopping services..."

	for group in $(GROUPS); do \
		for service in $$group/*; do \
			if grep -qE '^stop:' "$$service/Makefile" 2>/dev/null; then (cd "$$service" && $(MAKE) stop); fi; \
		done; \
	done

.PHONY: down
down:
	@echo "Stopping services and removing volumes..."

	for group in $(GROUPS); do \
		for service in $$group/*; do \
			if [ -f "$$service/docker-compose.yml" ] || [ -f "$$service/docker-compose.yaml" ]; then (cd "$$service" && docker compose down -v || true); fi; \
		done; \
	done

.PHONY: status
status:
	@docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

.PHONY: local-essential
local-essential: | fetch env local-build local-run-infra local-migrate local-run

.PHONY: start
start: | local-essential

.PHONY: build-% run-% migrate-% logs-% stop-%
build-%:
	@$(call in_service,$*,build)

run-%:
	@$(call in_service,$*,run)

migrate-%:
	@$(call in_service,$*,migrate)

logs-%:
	@$(call in_service,$*,logs)

stop-%:
	@$(call in_service,$*,stop)

define in_service
	service=$$(ls -d */$(1) 2>/dev/null | head -1); \
	test -n "$$service" || { echo "unknown service: $(1)"; exit 1; }; \
	cd "$$service" && $(MAKE) $(2)
endef
