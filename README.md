# DEPS

DEPS (Document Extraction & Processing System) is a document-processing platform for extracting structured data from invoices, IDs, contracts, and similar files.

It ships five extraction approaches:

- **Template** — OCR-based field extraction from a known layout
- **Prototype** — layout matching against a reference document
- **LLM Extractor** — AI-based extraction (via deps-ai-fusion)
- **Cloud Native Extraction** — attach a prebuilt or custom Azure Document Intelligence model
- **Custom Models** — write your own extraction logic and attach it as a plugin

Services are Docker microservices. The public entry point is nginx on [http://localhost:8000](http://localhost:8000).

## Extraction approaches

| Approach | How it works |
| --- | --- |
| Template | Fixed layout, fields extracted by position via OCR (`POST /api/v5/document-types/template`) |
| Prototype | Matches new documents against an uploaded reference layout (`POST /api/v5/document-types/prototype`) |
| LLM Extractor | An LLM answers field-extraction prompts against the document (`POST /api/v5/document-types/llm-extractor`), routed through `deps-ai-fusion` |
| Cloud Native Extraction | Attaches an Azure Document Intelligence model — either a Microsoft **prebuilt** model (e.g. `prebuilt-invoice`) or a **custom** model you trained in the Azure portal — via `POST /api/v5/document-types/azure-extractor` with `modelId`, `endpoint`, and `apiKey`. The API key is validated against Azure and stored in Azure Key Vault; field schema is synced from the model |
| Custom Models (plugins) | For fully custom extraction logic, build an **extraction plugin**: a standalone service that registers itself with `POST /api/v5/document-types/attach-extractor` (`extractorType: plugin`), then consumes document-extraction commands from its own RabbitMQ queue and writes results back. See `extraction-plugins/deps-all-fields-qa` for a working example and `extraction-plugins/deps-all-fields-qa-validation` for a validation-focused plugin |

## Prerequisites

- **GNU Make** — all setup and day-to-day commands go through the root `Makefile` (`make start`, `make apply-config`, …)
- **Docker Engine** with the **Docker Compose v2** plugin
- **Git** — `make fetch` asks whether to clone GitHub submodules over **HTTPS** or **SSH** (saved in this clone only). HTTPS needs no key for public repos; SSH needs a [GitHub SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh). Nested vendor libraries are still recorded as SSH URLs; the fetch wrapper rewrites them for this clone. Skip the prompt with `DEPS_GIT_PROTOCOL=https` or `DEPS_GIT_PROTOCOL=ssh`.
- **[Git LFS](https://git-lfs.github.com/)** — ML model weights (`*.pth`, `*.weights`) in services such as `deps-tables` are stored in LFS. Install it, then run `git lfs install` once before cloning so `make fetch` pulls the real files instead of pointer stubs
- **Python 3** and PyYAML (`pip install pyyaml`) — used by `make apply-config` and `make seed-demo-data`
- Free local ports: **8000** (app), **5432** (PostgreSQL), **5672** / **15672** (RabbitMQ). Kafka on **9092** is opt-in.
- A machine with 16 GB of free RAM and disk — first-time `make start` builds and runs many service images

## Quick start

```bash
git clone https://github.com/Siarhei-Shviadko/deps.git
cd deps
make start
```

Clone without `--recurse-submodules`. `make start` asks HTTPS vs SSH, then fetches nested services. Use `git@github.com:Siarhei-Shviadko/deps.git` if you prefer SSH for the root repo too.

`make start` runs: `prereq` → `fetch` → `env` → `apply-config` → `build` → `run-infra` → `run` → `migrate`.

`make env` copies `deps.yaml.example` to `deps.yaml` and **pauses**. Fill in credentials before continuing:

- Interactive wizard: `make setup-credentials`
- Or edit `deps.yaml` by hand

Then open [http://localhost:8000](http://localhost:8000). After the stack is up, optionally seed demo document types:

```bash
make seed-demo-data
```

## Step-by-step setup

Use this if you want to run each stage yourself, or to recover from a failed `make start`.

1. `make prereq` — create the shared Docker network `deps-network`
2. `make fetch` — clone/update all service submodules (prompts HTTPS vs SSH the first time; `make fetch-core-services`, `make fetch-feature-services`, and `make fetch-extraction-plugins` fetch one group at a time)
3. `make env` — create `deps.yaml` and empty `.env` files in each service
4. `make setup-credentials` *or* edit `deps.yaml` — then `make apply-config` to write credentials into service env files
5. `make build` — build all service Docker images
6. `make run-infra` — start PostgreSQL, RabbitMQ, and LiteLLM
7. `make run` — start every application service
8. `make migrate` — apply database migrations

## Configuration

All credentials live in `deps.yaml` (gitignored). `deps.yaml.example` documents every key. Apply changes with `make apply-config` (restart affected services afterwards).

| Area | Default | Optional upgrades |
| --- | --- | --- |
| OCR | Tesseract (no key, lower quality) | Azure Form Recognizer, AWS Textract (needs an S3 bucket — `ocr.aws_textract.s3_bucket_name`), GCP Vision |
| LLM | none | EPAM DIAL, Azure OpenAI, OpenAI, AWS Bedrock, Google Gemini, Deepseek, Groq — at least one is required for LLM Extractor document types |
| Storage | local MinIO | Azure Blob, AWS S3, GCP |
| Cloud Native Extraction | disabled | Azure Key Vault service principal (`parsing.cloud_native_extraction`: `azure_vault_url`, `client_id`, `tenant_id`, `client_secret`) — required so `deps-cloud-native-extraction` can store the per-document-type Azure Document Intelligence API keys you supply via the API |
| Other | frontend OIDC (`AUTH_TYPE=oidc`, EPAM Keycloak `deps-client-dev`); IAM auth off | SMTP (invite emails), Elastic APM, Google Drive / OneDrive pickers |

Tesseract is enough to start Template extraction. Configure a paid OCR engine for Prototype and LLM document types, and at least one LLM provider for AI extraction. AWS Textract additionally needs a real AWS S3 bucket (`ocr.aws_textract.s3_bucket_name` / `s3_endpoint_url`) so `deps-parsing` can upload documents for Textract to read — local MinIO is not enough. Cloud Native Extraction additionally needs the Key Vault credentials above before you can attach any Azure Document Intelligence model to a document type.

## Try the demo data

With the stack running:

```bash
make seed-demo-data
```

This creates three demo document types (Template invoice, Prototype ID card, LLM service agreement) and uploads one sample document each. Safe to re-run: existing types and documents are skipped.

If no LLM credentials are configured, the LLM Extractor type is skipped and the script prints how to add them. The Template type always uses Tesseract. If no paid OCR engine is configured, Prototype and LLM Extractor fall back to Tesseract with a quality warning.

## Everyday operations

```bash
make status              # running containers
make logs                # docker compose logs for every service
make stop                # stop containers without removing them
make down                # stop and remove containers (volumes are kept)
make pull                # discard local changes, pull latest, update submodules to recorded SHAs
make update              # latest first-level services from origin; nested vendors stay at SHAs those services recorded
```

## Repository layout

```
core-services/       # platform services (api-gateway, backend, iam, nginx, infra, …)
feature-services/    # optional features (ai-fusion, template, prototype, enrichment, …)
extraction-plugins/  # extraction plugins
```

All orchestration is through the root `Makefile`. 