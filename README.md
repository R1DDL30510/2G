# Local AI Infrastructure (Cloud-Independent, OSS)

This repository scaffolds a local, open-source AI stack using Docker Compose. It runs fully on your machine with no cloud dependency.

## Prerequisites
- Windows 11 (WSL2 optional), admin rights
- Docker Desktop (with "Use the WSL 2 based engine" enabled)
- Git

Optional: Python 3.10+, Node.js LTS, PowerShell 7 for scripts.

## Quickstart
1. Initialize the workspace: `./scripts/bootstrap.ps1 -PromptSecrets` (creates `.env`, `data/`, and `models/`, and lets you confirm CLI keys interactively).
2. Adjust `.env` if you need different ports or storage paths.
3. Start the stack: `./scripts/compose.ps1 up` (PowerShell).
4. Open WebUI: http://localhost:3000 (connects to local Ollama at http://localhost:11434).

## Validation & Health Checks
- Generate a host environment fingerprint with `./scripts/bootstrap.ps1 -Report` (writes `docs/ENVIRONMENT.md`).
- Run a guarded evaluation sweep: `./scripts/context-sweep.ps1 -CpuOnly -Safe -WriteReport` (outputs `docs/CONTEXT_RESULTS_*.md`).
- Tail combined service logs: `./scripts/compose.ps1 logs`.

The compose stack is pinned to `ollama/ollama:0.3.14`, `ghcr.io/open-webui/open-webui:v0.3.7`, and `qdrant/qdrant:v1.15.4`. Update the tags in `infra/compose/docker-compose.yml` after validating new releases.

## Codex CLI Integration
- The Codex CLI expects an API key even when proxying to local Ollama. `./scripts/bootstrap.ps1` ensures `.env` contains `OLLAMA_API_KEY=ollama-local`; rerun with `-PromptSecrets` or edit `.env` to change it.
- Export `OLLAMA_API_KEY` from `.env` before invoking the CLI so requests succeed without breaking automation flows.
- The bootstrap script also warns when the `codex` executable is missing, highlighting prerequisites before you start compose operations.

## Components
- Ollama (`ollama/ollama:0.3.14`): Local LLM runtime and model manager
- Open WebUI (`ghcr.io/open-webui/open-webui:v0.3.7`): Web interface for chat and orchestration
- Qdrant (`qdrant/qdrant:v1.15.4`): Vector database for embeddings/RAG

See `docs/ARCHITECTURE.md` for details.

## Development
- Edit compose config in `infra/compose/docker-compose.yml`.
- Place persistent data under `data/` and models under `models/` (git-ignored).
- Update environment report via `./scripts/bootstrap.ps1 -Report` and read `docs/ENVIRONMENT.md`.

## Documentation & Reports
- `docs/PROJECT_REPORT_2025-09-16.md`: Full operational and risk report covering stack status, tooling, and recommendations.
- `docs/ARCHITECTURE.md`: High-level service layout and networking overview.
- `docs/RELEASE_v2025-09-16.md`: Latest release notes and operational checklist.
- `docs/CONTEXT_RESULTS_*.md`: Historical context sweep outcomes.
- `docs/STACK_STATUS_2025-09-16.md`: Snapshot of available tooling, outstanding gaps, and next validation actions.
- `docs/ENVIRONMENT.md`: Generated host environment fingerprint (regenerate after host changes).


