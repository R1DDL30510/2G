# Repository Guidelines

## Project Structure & Module Organization
- Compose stack lives under `infra/compose/`; `docker-compose.yml` orchestrates Ollama, Open WebUI, and Qdrant.
- PowerShell helpers in `scripts/` (e.g., `compose.ps1`, `model.ps1`, `context-sweep.ps1`) manage lifecycle, models, and diagnostics.
- Custom Ollama `Modelfile` definitions reside in `modelfiles/`; persisted embeddings live in `data/` and model caches in `models/` (both gitignored).
- Mirror implementation modules in `src/` with matching specs in `tests/`; keep shared prompts and evidence in `docs/`.

## Build, Test, and Development Commands
- `./scripts/bootstrap.ps1 -PromptSecrets` provisions `.env`, initializes storage, and surfaces optional diagnostics.
- `./scripts/compose.ps1 up|down|restart|logs` manages the full stack from PowerShell.
- `docker compose -f infra/compose/docker-compose.yml up -d` runs services headless for CI or remote hosts.
- `./scripts/model.ps1 pull -Model llama3.1:8b` fetches models; pair with `list` or `create-all` to audit local inventory.
- `pip install -r requirements/python/dev.txt && pytest` executes smoke tests that validate compose manifests, Modelfiles, and `.env.example` defaults.

## Coding Style & Naming Conventions
- Follow `.editorconfig`: 2 spaces for JavaScript, TypeScript, JSON, YAML, and Markdown; 4 spaces for Python, C#, and PowerShell.
- Use kebab-case filenames for JS/TS, snake_case for Python, and PascalCase for PowerShell cmdlets.
- Run language-specific formatters or linters before committing and keep module structure mirrored between `src/` and `tests/`.

## Testing Guidelines
- Place unit tests under `tests/` beside their implementation peers and stub external integrations.
- Keep test runs offline and deterministic; capture new fixtures under `tests/fixtures/` when necessary.
- For integration evidence, run `./scripts/context-sweep.ps1 -Safe -WriteReport` (add `-CpuOnly` when GPUs are unavailable); reports land in `docs/CONTEXT_RESULTS_*.md` and are mirrored under `docs/evidence/context/`.

## Commit & Pull Request Guidelines
- Use Conventional Commit prefixes such as `feat:`, `fix:`, and `chore:` with clear scopes.
- Reference related work (`Closes #123`), summarize behavior changes, and attach logs or screenshots when output shifts.
- Verify `./scripts/compose.ps1 up` succeeds locally and rerun relevant sweeps before requesting review.

## Security & Configuration Tips
- Never commit secrets; sync `.env` with `.env.example` using `./scripts/bootstrap.ps1 -PromptSecrets` when credentials change.
- The stack pins `ollama/ollama:0.3.11`, `ghcr.io/open-webui/open-webui:v0.3.7`, and `qdrant/qdrant:v1.15.4`; validate updates on a branch before promoting.
- Store large artifacts in `data/` or `models/`, and export backups prior to pruning containers or volumes.
