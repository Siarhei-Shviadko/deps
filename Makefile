-include .env
-include Makefile.local

export PATH := $(CURDIR)/bin:$(PATH)

.PHONY: prereq
prereq:
	docker network create deps-network || true

.PHONY: fetch-core-services
fetch-core-services:
	bin/git-protocol run git submodule update --init --recursive core-services/

.PHONY: fetch-feature-services
fetch-feature-services:
	bin/git-protocol run git submodule update --init --recursive feature-services/

.PHONY: fetch-extraction-plugins
fetch-extraction-plugins:
	bin/git-protocol run git submodule update --init --recursive extraction-plugins/

.PHONY: fetch
fetch: | fetch-core-services fetch-feature-services fetch-extraction-plugins

.PHONY: env
env:
	test -f deps.yaml || cp deps.yaml.example deps.yaml
	@echo ""
	@echo "deps.yaml has been created. Fill in your credentials before continuing:"
	@echo "  Interactive wizard : make setup-credentials"
	@echo "  Manual             : edit deps.yaml in your editor"
	@echo ""
	@echo "After the stack is running, optionally seed demo document types:"
	@echo "  make seed-demo-data"
	@echo ""
	@printf 'Press Enter when done (Ctrl+C to abort)...' && read _
	touch core-services/deps-api-gateway/.env
	touch core-services/deps-backend/.env
	touch core-services/deps-document-type/.env
	touch core-services/deps-event-relay/.env
	touch core-services/deps-extraction/.env
	touch core-services/deps-file-storage/.env
	touch core-services/deps-frontend/.env
	touch core-services/deps-generic-unifier-plugin/.env
	touch core-services/deps-high-sparrow/.env
	touch core-services/deps-iam/.env
	touch core-services/deps-nginx/.env
	touch core-services/deps-ocr-gateway/.env
	touch core-services/deps-parsing/.env
	touch core-services/deps-unifier/.env
	touch core-services/deps-workflow-manager/.env
	touch feature-services/deps-ai-fusion/.env
	touch feature-services/deps-enrichment/.env
	touch feature-services/deps-output-exporting/.env
	touch feature-services/deps-agentic-ai/.env
	touch feature-services/deps-file/.env
	touch feature-services/deps-groups/.env
	touch feature-services/deps-meta-agent/.env
	touch feature-services/deps-prototype/.env
	touch feature-services/deps-template/.env
	touch feature-services/deps-files-batch/.env
	touch feature-services/deps-classification/.env
	touch feature-services/deps-tables/.env
	touch feature-services/deps-image-preprocess/.env
	touch extraction-plugins/deps-all-fields-qa/.env
	touch extraction-plugins/deps-all-fields-qa-validation/.env
	touch core-services/deps-litellm/.env

.PHONY: build
build:
	cd core-services/deps-api-gateway && make build
	cd core-services/deps-backend && make build
	cd core-services/deps-document-type && make build
	cd core-services/deps-event-relay && make build
	cd core-services/deps-extraction && make build
	cd core-services/deps-file-storage && make build
	cd core-services/deps-frontend && make build
	cd core-services/deps-generic-unifier-plugin && make build
	cd core-services/deps-high-sparrow && make build
	cd core-services/deps-iam && make build
	cd core-services/deps-nginx && make build
	cd core-services/deps-ocr-gateway && make build
	cd core-services/deps-parsing && make build
	cd core-services/deps-unifier && make build
	cd core-services/deps-workflow-manager && make build
	cd feature-services/deps-ai-fusion && make build
	cd feature-services/deps-enrichment && make build
	cd feature-services/deps-output-exporting && make build
	cd feature-services/deps-file && make build
	cd feature-services/deps-groups && make build
	cd feature-services/deps-prototype && make build
	cd feature-services/deps-template && make build
	cd feature-services/deps-files-batch && make build
	cd feature-services/deps-image-preprocess && make build
	cd feature-services/deps-classification && make build
	cd feature-services/deps-tables && make build

.PHONY: run-infra
run-infra:
	cd core-services/deps-infra && make run
	cd core-services/deps-litellm && make run

.PHONY: run
run:
	cd core-services/deps-api-gateway && docker compose up -d
	cd core-services/deps-backend && docker compose up -d
	cd core-services/deps-document-type && docker compose up -d
	cd core-services/deps-event-relay && docker compose up -d
	cd core-services/deps-extraction && docker compose up -d
	cd core-services/deps-file-storage && docker compose up -d
	cd core-services/deps-frontend && docker compose up -d
	cd core-services/deps-generic-unifier-plugin && docker compose up -d
	cd core-services/deps-high-sparrow && docker compose up -d
	cd core-services/deps-iam && docker compose up -d
	cd core-services/deps-nginx && docker compose up -d
	cd core-services/deps-ocr-gateway && docker compose up -d
	cd core-services/deps-parsing && docker compose up -d
	cd core-services/deps-unifier && docker compose up -d
	cd core-services/deps-workflow-manager && docker compose up -d
	cd feature-services/deps-ai-fusion && docker compose up -d
	cd feature-services/deps-enrichment && docker compose up -d
	cd feature-services/deps-output-exporting && docker compose up -d
	cd feature-services/deps-file && docker compose up -d
	cd feature-services/deps-groups && docker compose up -d
	cd feature-services/deps-prototype && docker compose up -d
	cd feature-services/deps-template && docker compose up -d
	cd feature-services/deps-files-batch && docker compose up -d
	cd feature-services/deps-classification && docker compose up -d
	cd feature-services/deps-image-preprocess && docker compose up -d
	cd feature-services/deps-tables && docker compose up -d

.PHONY: migrate
migrate:
	cd core-services/deps-backend && make migrate
	cd core-services/deps-iam && make migrate
	cd core-services/deps-file-storage && make migrate
	cd core-services/deps-document-type && make migrate
	cd core-services/deps-extraction && make migrate
	cd core-services/deps-high-sparrow && make migrate
	cd core-services/deps-unifier && make migrate
	cd core-services/deps-workflow-manager && make migrate
	cd core-services/deps-parsing && make migrate
	cd feature-services/deps-ai-fusion && make migrate
	cd feature-services/deps-enrichment && make migrate
	cd feature-services/deps-output-exporting && make migrate
	cd feature-services/deps-file && make migrate
	cd feature-services/deps-groups && make migrate
	cd feature-services/deps-prototype && make migrate
	cd feature-services/deps-template && make migrate
	cd feature-services/deps-files-batch && make migrate
	cd feature-services/deps-classification && make migrate

.PHONY: setup-credentials
setup-credentials:
	bin/setup-credentials

.PHONY: seed-demo-data
seed-demo-data:
	python3 bin/seed-demo-data

.PHONY: apply-config
apply-config:
	python3 bin/apply-config

.PHONY: start
start: | prereq fetch env apply-config build run-infra run migrate

.PHONY: down
down:
	cd core-services/deps-api-gateway && docker compose down
	cd core-services/deps-backend && docker compose down
	cd core-services/deps-document-type && docker compose down
	cd core-services/deps-event-relay && docker compose down
	cd core-services/deps-extraction && docker compose down
	cd core-services/deps-file-storage && docker compose down
	cd core-services/deps-frontend && docker compose down
	cd core-services/deps-generic-unifier-plugin && docker compose down
	cd core-services/deps-high-sparrow && docker compose down
	cd core-services/deps-iam && docker compose down
	cd core-services/deps-nginx && docker compose down
	cd core-services/deps-ocr-gateway && docker compose down
	cd core-services/deps-parsing && docker compose down
	cd core-services/deps-unifier && docker compose down
	cd core-services/deps-workflow-manager && docker compose down
	cd feature-services/deps-ai-fusion && docker compose down
	cd feature-services/deps-enrichment && docker compose down
	cd feature-services/deps-output-exporting && docker compose down
	cd feature-services/deps-file && docker compose down
	cd feature-services/deps-groups && docker compose down
	cd feature-services/deps-prototype && docker compose down
	cd feature-services/deps-template && docker compose down
	cd feature-services/deps-files-batch && docker compose down
	cd feature-services/deps-classification && docker compose down
	cd feature-services/deps-image-preprocess && docker compose down
	cd feature-services/deps-tables && docker compose down
	cd core-services/deps-infra && docker compose down
	cd core-services/deps-litellm && docker compose down

.PHONY: logs
logs:
	cd core-services/deps-api-gateway && docker compose logs
	cd core-services/deps-backend && docker compose logs
	cd core-services/deps-document-type && docker compose logs
	cd core-services/deps-event-relay && docker compose logs
	cd core-services/deps-extraction && docker compose logs
	cd core-services/deps-file-storage && docker compose logs
	cd core-services/deps-frontend && docker compose logs
	cd core-services/deps-generic-unifier-plugin && docker compose logs
	cd core-services/deps-high-sparrow && docker compose logs
	cd core-services/deps-iam && docker compose logs
	cd core-services/deps-nginx && docker compose logs
	cd core-services/deps-ocr-gateway && docker compose logs
	cd core-services/deps-parsing && docker compose logs
	cd core-services/deps-unifier && docker compose logs
	cd core-services/deps-workflow-manager && docker compose logs
	cd feature-services/deps-ai-fusion && docker compose logs
	cd feature-services/deps-enrichment && docker compose logs
	cd feature-services/deps-output-exporting && docker compose logs
	cd feature-services/deps-file && docker compose logs
	cd feature-services/deps-groups && docker compose logs
	cd feature-services/deps-prototype && docker compose logs
	cd feature-services/deps-template && docker compose logs
	cd feature-services/deps-files-batch && docker compose logs
	cd feature-services/deps-classification && docker compose logs
	cd feature-services/deps-image-preprocess && docker compose logs
	cd feature-services/deps-tables && docker compose logs
	cd core-services/deps-infra && docker compose logs

.PHONY: stop
stop:
	cd core-services/deps-api-gateway && make stop
	cd core-services/deps-backend && make stop
	cd core-services/deps-document-type && make stop
	cd core-services/deps-event-relay && make stop
	cd core-services/deps-extraction && make stop
	cd core-services/deps-file-storage && make stop
	cd core-services/deps-generic-unifier-plugin && make stop
	cd core-services/deps-high-sparrow && make stop
	cd core-services/deps-iam && make stop
	cd core-services/deps-ocr-gateway && make stop
	cd core-services/deps-parsing && make stop
	cd core-services/deps-unifier && make stop
	cd core-services/deps-workflow-manager && make stop
	cd feature-services/deps-ai-fusion && make stop
	cd feature-services/deps-enrichment && make stop
	cd feature-services/deps-output-exporting && make stop
	cd feature-services/deps-file && make stop
	cd feature-services/deps-groups && make stop
	cd feature-services/deps-prototype && make stop
	cd feature-services/deps-template && make stop
	cd feature-services/deps-files-batch && make stop
	cd feature-services/deps-classification && make stop
	cd feature-services/deps-image-preprocess && make stop
	cd feature-services/deps-tables && make stop
	cd core-services/deps-litellm && docker compose stop
	cd core-services/deps-infra && docker compose stop

.PHONY: status
status:
	@docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

.PHONY: pull
pull:
	@echo -n "This will discard local changes and pull latest. Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	git restore --staged . && git restore .
	git pull
	bin/git-protocol run git submodule update --init --recursive

.PHONY: update
update:
	@echo -n "This will discard local changes, pull the root repo, and check out the latest first-level services (nested vendors stay at the SHAs those services recorded). Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	git restore --staged . && git restore .
	git pull || echo "Warning: could not pull root repo (skipping)"
	git submodule foreach --recursive 'git restore --staged . && git restore . || true'
	bin/update-services
