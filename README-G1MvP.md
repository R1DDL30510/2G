# Local AI Infrastructure (Cloud-Independent, OSS)

This repository provisions a local, open-source AI stack with Docker Compose. Everything runs on your workstation with no external cloud services required.

> **Note:** `README.md` now carries the canonical runbook and expanded diagnostics guidance. Use this file for a condensed summary when you only need the quickstart checklist.

## Stack Overview
- Compose stack pins `ollama/ollama:0.3.11`, `ghcr.io/open-webui/open-webui:v0.3.7`, and `qdrant/qdrant:v1.15.4` for deterministic start-ups.
- Ollama hosts and serves local LLMs, Open WebUI provides the chat UI, and Qdrant offers vector search for retrieval-augmented workflows.

## Directory Layout
- `infra/compose/`  primary `docker-compose.yml` plus future overrides.
- `scripts/`  PowerShell helpers (`compose.ps1`, `model.ps1`, `context-sweep.ps1`, `eval-context.ps1`).
- `modelfiles/`  custom Ollama Modelfiles tracked in git.
- `data/`, `models/`  persistent volumes and caches (ignored by git).
- `docs/`  architecture notes, release reports, and context evaluation outputs.
- `src/`, `tests/`  application code and mirrored test suites (add as needed).

## Prerequisites
- Windows 11 (WSL2 optional) with administrator rights.
- Docker Desktop using the WSL 2 engine.
- Git; optionally PowerShell 7, Python 3.10+, and Node.js LTS for tooling.

## Quickstart
1. Copy `.env.example` to `.env` and adjust ports or storage paths.
2. Start the stack: `./scripts/compose.ps1 up`.
3. Open http://localhost:3000 for Open WebUI (talks to Ollama at http://localhost:11434 and Qdrant at http://localhost:6333).

## Operations & Validation
- `./scripts/compose.ps1 up|down|restart|logs`  manage the compose services.
- `docker compose -f infra/compose/docker-compose.yml up -d`  direct compose invocation for automation.
- `./scripts/model.ps1 list|pull|create-all`  manage base and custom Ollama models.
- `./scripts/context-sweep.ps1 -Safe -WriteReport`  integration sweep that captures GPU validation evidence (append `-CpuOnly` only when a CUDA-capable device is unavailable) and emits `docs/CONTEXT_RESULTS_*.md`.
- `./scripts/eval-context.ps1 -Model llama31-8b-c8k -TokensTarget 6000`  targeted evaluation run.

## Maintenance Tips
- Keep `.env` in sync with `.env.example`; never commit secrets.
- Persist service data under `data/` and model caches under `models/` before pruning containers.
- Review release guidance in `docs/RELEASE_v2025-09-16.md` and update image pins only after validating new versions.
- Generate environment fingerprints with `./scripts/bootstrap.ps1 -Report` when onboarding new machines.



