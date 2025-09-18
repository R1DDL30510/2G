# Windows Release Prep Overview

## Purpose & Scope
- Summarizes the local AI stack that runs on Windows hosts with Docker Desktop and PowerShell tooling so operators can verify what is production ready today and what still needs work before tagging a release. 【F:README.md†L5-L26】【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L54】
- Focuses on the cleaned-up workflows that already function (bootstrap provisioning, compose lifecycle, diagnostics) and highlights remaining gaps (GPU sweeps, coverage, MCP integration). 【F:docs/STACK_STATUS_2025-09-16.md†L3-L37】【F:docs/COVERAGE_REPORT_2025-09-17.md†L21-L53】

## Stack Components at a Glance
| Service | Image & Version | Role | Windows Host Port |
|---------|-----------------|------|-------------------|
| Ollama | `ollama/ollama:0.3.14` | Local LLM runtime and model manager. | `11434` | 【F:README.md†L41-L44】【F:infra/compose/docker-compose.yml†L1-L14】
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.3.7` | Chat and orchestration UI backed by Ollama. | `3000` | 【F:README.md†L15-L16】【F:infra/compose/docker-compose.yml†L16-L28】
| Qdrant | `qdrant/qdrant:v1.15.4` | Vector store for embeddings/RAG flows. | `6333` | 【F:README.md†L41-L44】【F:infra/compose/docker-compose.yml†L29-L35】

Data folders (`data/`, `models/`, `docs/evidence/`) are created by the bootstrap script and map into the containers for persistence. 【F:scripts/bootstrap.ps1†L366-L376】【F:README.md†L48-L50】

## What Works Today
- **Bootstrap provisioning** – `./scripts/bootstrap.ps1 -PromptSecrets` seeds `.env`, ensures storage folders exist, validates Docker/curl presence, and can run interactively via the menu. 【F:README.md†L12-L24】【F:scripts/bootstrap.ps1†L360-L395】【F:scripts/bootstrap.ps1†L418-L455】
- **Compose lifecycle** – `./scripts/compose.ps1` wraps `docker compose` for `up`, `down`, `restart`, and `logs`, and CI consumes the CPU override manifest. 【F:docs/STACK_STATUS_2025-09-16.md†L12-L13】
- **Model management** – `./scripts/model.ps1 create-all -MainGpu <index>` provisions Modelfiles so Windows hosts can recreate long-context and GPU variants after bootstrap. 【F:docs/STACK_STATUS_2025-09-16.md†L7-L14】
- **Diagnostics & evidence** – Context sweeps, benchmarks, and host state capture are wired into scripts and store artifacts under `docs/evidence/` when run. 【F:README.md†L20-L34】【F:docs/STACK_STATUS_2025-09-16.md†L14-L17】【F:scripts/bootstrap.ps1†L418-L455】
- **Smoke testing** – `pip install -r requirements/python/dev.txt && pytest` passes (13 tests) and guards compose manifests, Modelfiles, and `.env.example` defaults. 【F:README.md†L20-L26】【F:docs/STACK_STATUS_2025-09-16.md†L19-L22】

## Outstanding Gaps
- GPU-enabled sweeps and performance benchmarks remain pending; current evidence is CPU-only. 【F:docs/STACK_STATUS_2025-09-16.md†L23-L27】【F:docs/COVERAGE_REPORT_2025-09-17.md†L25-L33】
- PowerShell 7 adoption is still required on operator machines to unlock local Pester runs. 【F:docs/STACK_STATUS_2025-09-16.md†L22-L28】
- Automated coverage instrumentation and CI release gates are missing, so the stack is **not release ready** yet. 【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L54】
- MCP toolkit support has not been integrated or documented in the repository; search returns no references, so installation remains a follow-up item. 【fd48a5†L1-L2】

## Minimum Stable Function Set for Windows Hosts
1. **Provision environment** – Run `./scripts/bootstrap.ps1 -PromptSecrets` to generate `.env`, populate diagnostics defaults, and capture an optional environment report (`-Report`). 【F:README.md†L12-L24】【F:docs/STACK_STATUS_2025-09-16.md†L5-L21】
2. **Start core services** – Launch the compose stack via `./scripts/compose.ps1 up` (or `docker compose -f infra/compose/docker-compose.yml up -d`) and confirm Ollama, Open WebUI, and Qdrant respond on their pinned ports. 【F:README.md†L15-L16】【F:docs/STACK_STATUS_2025-09-16.md†L31-L34】
3. **Install models** – Execute `./scripts/model.ps1 create-all -MainGpu <index>` followed by `./scripts/model.ps1 list` to ensure the RAG-ready model set exists on disk. 【F:docs/STACK_STATUS_2025-09-16.md†L7-L14】【F:docs/STACK_STATUS_2025-09-16.md†L34-L35】
4. **Validate diagnostics** – Run `./scripts/context-sweep.ps1 -Safe -Profile llama31-long -WriteReport`, `./scripts/clean/capture_state.ps1`, and `./scripts/clean/bench_ollama.ps1` to populate evidence with current metrics. 【F:docs/STACK_STATUS_2025-09-16.md†L14-L17】【F:docs/STACK_STATUS_2025-09-16.md†L35-L36】
5. **Run smoke tests** – `pip install -r requirements/python/dev.txt && pytest` must pass locally before promoting a build. 【F:README.md†L20-L26】【F:docs/STACK_STATUS_2025-09-16.md†L19-L22】

This set mirrors the operator checklist already tracked in the stack status report and defines the minimal reproducible workflow we can stand behind on Windows. 【F:docs/STACK_STATUS_2025-09-16.md†L31-L37】

## Bootstrap Menu Flow (Call-and-Run)
- The PowerShell menu exposes provisioning, reporting, GPU evaluation, host checks, state capture, and benchmarking actions behind numbered shortcuts, enabling one-call bring-up on fresh hosts. 【F:scripts/bootstrap.ps1†L418-L455】
- Use `./scripts/bootstrap.ps1 -Menu` to relaunch the menu after provisioning or `./scripts/bootstrap.ps1 -NoMenu` to skip it in unattended runs. 【F:README.md†L12-L24】
- Each menu invocation reuses the same helper functions, so recorded evidence and `.env` updates stay consistent across manual and automated sessions. 【F:scripts/bootstrap.ps1†L366-L455】

## MCP Toolkit Integration Plan for RAG
- **Current state** – No MCP tooling exists in the repo, so any Model Context Protocol workflow must be added manually. 【fd48a5†L1-L2】
- **Recommended path**
  1. Select an MCP distribution that supports Windows (e.g., CLI or SDK) and document installation prerequisites alongside Docker and PowerShell requirements.
  2. Extend `scripts/bootstrap.ps1` with an optional menu entry that checks for the MCP executable/library and offers to install or link it.
  3. Capture configuration in `.env` (API endpoints, credentials) once the toolkit is validated, mirroring how Codex CLI hints are surfaced today. 【F:README.md†L36-L39】【F:scripts/bootstrap.ps1†L366-L395】
  4. Add smoke coverage that exercises MCP-backed RAG retrieval once the integration is in place, publishing results under `docs/evidence/` like existing sweeps. 【F:docs/COVERAGE_REPORT_2025-09-17.md†L45-L54】

Documenting these steps now ensures the release plan captures MCP adoption even though implementation will land on a follow-up branch.

## Release Readiness Actions
- Complete GPU-enabled sweeps and persist benchmarks before tagging. 【F:docs/STACK_STATUS_2025-09-16.md†L25-L27】【F:docs/COVERAGE_REPORT_2025-09-17.md†L25-L33】
- Migrate operators to PowerShell 7+ (or ship PowerShell Core with the toolchain) to unlock local Pester coverage. 【F:docs/STACK_STATUS_2025-09-16.md†L22-L28】
- Add coverage instrumentation and enforce CI gates so automation produces publishable artifacts. 【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L54】
- Track MCP toolkit integration as a release blocker once the above validation is in place. 【fd48a5†L1-L2】【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L54】
