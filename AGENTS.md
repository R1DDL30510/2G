# Repository Guidelines

## Project Structure & Module Organization
- Compose stack lives under `infra/compose/`; `docker-compose.yml` wires Ollama, Open WebUI, and Qdrant with shared volumes and network aliases.
- PowerShell helpers in `scripts/` (e.g., `compose.ps1`, `model.ps1`, `context-sweep.ps1`) manage lifecycle tasks, cached models, and diagnostic sweeps.
- Custom Ollama `Modelfile` definitions reside in `modelfiles/`; persisted embeddings land in `data/` and model caches in `models/` (both gitignored).
- Mirror implementation modules in `src/` with matching specs in `tests/`, and keep shared prompts, context sweeps, and other evidence in `docs/`.

## Build, Test, and Development Commands
- `./scripts/bootstrap.ps1 -PromptSecrets` provisions `.env`, initializes storage, and surfaces optional diagnostics for new contributors.
- `./scripts/compose.ps1 up|down|restart|logs` manages the full stack from PowerShell; prefer `up` before local changes and `logs` for quick triage.
- `docker compose -f infra/compose/docker-compose.yml up -d` runs services headless for CI or remote hosts without the helper scripts.
- `./scripts/model.ps1 pull -Model llama3.1:8b` fetches models; pair with `list` or `create-all` to audit or hydrate the local inventory.
- `pip install -r requirements-dev.txt && pytest` executes smoke tests that validate compose manifests, Modelfiles, and `.env.example` defaults.

## Coding Style & Naming Conventions
- Follow `.editorconfig`: use 2 spaces for JavaScript, TypeScript, JSON, YAML, and Markdown; 4 spaces for Python, C#, and PowerShell.
- Use kebab-case filenames for JS/TS modules, snake_case for Python packages, and PascalCase for PowerShell cmdlets and functions.
- Run language-specific formatters or linters before committing, and keep module structure mirrored between `src/` and `tests/` for discoverability.

## Testing Guidelines
- Place unit tests under `tests/` beside their implementation peers and stub external integrations to keep runs deterministic.
- Capture new fixtures under `tests/fixtures/` when scenarios need canned inputs; store bulky assets outside of version control.
- Run `./scripts/context-sweep.ps1 -Safe -WriteReport` (add `-CpuOnly` when GPUs are unavailable); reports land in `docs/CONTEXT_RESULTS_*.md` for review.

## Commit & Pull Request Guidelines
- Use Conventional Commit prefixes such as `feat:`, `fix:`, and `chore:` with clear scopes that hint at impacted areas or scripts.
- Reference related work (`Closes #123`), summarize behavior changes, and attach logs or screenshots when output shifts.
- Verify `./scripts/compose.ps1 up` succeeds locally and rerun relevant sweeps before requesting review to prevent environment regressions.

## Security & Configuration Tips
- Never commit secrets; sync `.env` with `.env.example` using `./scripts/bootstrap.ps1 -PromptSecrets` when credentials change or rotate.
- The stack pins `ollama/ollama:0.3.14`, `ghcr.io/open-webui/open-webui:v0.3.7`, and `qdrant/qdrant:v1.15.4`; validate updates on a branch before promoting.
- Store large artifacts in `data/` or `models/`, and export backups prior to pruning containers, volumes, or cached embeddings.
