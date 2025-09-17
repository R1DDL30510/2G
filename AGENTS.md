# Repository Guidelines

## Project Structure & Module Organization
This repo centers on the compose stack under `infra/compose/`, where `docker-compose.yml` wires together Ollama, Open WebUI, and Qdrant.
PowerShell lifecycle helpers live in `scripts/` (e.g., `compose.ps1`, `model.ps1`, `context-sweep.ps1`).
Custom Ollama `Modelfile` definitions reside in `modelfiles/`.
Persisted embeddings and chat logs belong in `data/`, while model caches stay in `models/` (both gitignored).
When adding application code, mirror modules between `src/` and `tests/` so implementations and specs share paths.

## Build, Test, and Development Commands
`./scripts/compose.ps1 up` brings up the full stack with pinned services; use `down`, `restart`, or `logs` for matching lifecycle operations.
`docker compose -f infra/compose/docker-compose.yml up -d` starts the same topology headless for automation contexts.
Manage Ollama models through `./scripts/model.ps1 list`, `pull`, or `create-all`; for example, `./scripts/model.ps1 pull -Model llama3.1:8b`.

## Coding Style & Naming Conventions
Follow `.editorconfig`: 2-space indentation for JavaScript, TypeScript, JSON, YAML, and Markdown; 4-space indentation for Python, C#, and PowerShell.
Use kebab-case filenames for JS/TS, snake_case for Python, and PascalCase for PowerShell cmdlets.
Run language-appropriate formatters or linters before committing and align new directories with existing module structure.

## Testing Guidelines
Keep unit tests offline and colocated under `tests/`, stubbing external integrations while covering new behavior.
For integration validation, run `./scripts/context-sweep.ps1 -CpuOnly -Safe -WriteReport`; reports land in `docs/CONTEXT_RESULTS_*.md`.

## Commit & Pull Request Guidelines
Use Conventional Commit prefixes such as `feat:`, `fix:`, or `chore:` to describe changes.
Pull requests must explain intent, reference issues (e.g., `Closes #123`), and attach screenshots or logs when behavior shifts.
Verify the compose stack locally before requesting review and rerun relevant sweeps to guard against regressions.

## Security & Configuration Tips
Never commit secrets; sync `.env` with `.env.example` when configuring environments.
The stack pins `ollama/ollama:0.3.14`, `ghcr.io/open-webui/open-webui:v0.3.7`, and `qdrant/qdrant:v1.15.4`; validate updates in a branch before promoting.
Store large artifacts in `data/` or `models/`, and export backups prior to pruning containers.
