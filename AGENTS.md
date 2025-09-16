# Repository Guidelines

## Project Structure & Module Organization
Compose assets live under `infra/compose/`, with `docker-compose.yml` orchestrating Ollama, Open WebUI, and Qdrant. PowerShell helpers in `scripts/` keep lifecycle tasks consistent; prefer them over ad-hoc docker commands. Custom Ollama definitions sit in `modelfiles/`, while long-lived data lands in `data/` and model caches in `models/` (both ignored). Check documentation, context reports, and release notes in `docs/`. If you add application code, mirror its structure between `src/` and `tests/` so modules and specs stay discoverable.

## Build, Test, and Development Commands
- `./scripts/compose.ps1 up|down|restart|logs` - manage the full stack using the pinned compose file.
- `docker compose -f infra/compose/docker-compose.yml up -d` - direct launch for automation contexts.
- `./scripts/model.ps1 list|pull|create-all` - inspect, fetch, or register Modelfile-based variants (e.g., `./scripts/model.ps1 pull -Model llama3.1:8b`).
- `./scripts/context-sweep.ps1 -CpuOnly -Safe -WriteReport` - run guarded end-to-end validations that publish under `docs/`.

## Coding Style & Naming Conventions
Follow `.editorconfig`: 2 spaces for JavaScript, TypeScript, JSON, YAML, and Markdown; 4 spaces for Python, C#, and PowerShell. Use kebab-case for JS/TS files, snake_case for Python, and PascalCase for PowerShell cmdlets. Run any language-specific formatter or linter before you push changes.

## Testing Guidelines
Unit tests should mirror the module layout inside `tests/`. Keep unit scope offline and stub external calls. For integration checks, rely on the context sweep and evaluation scripts; start with CPU-safe modes before enabling full GPU runs. Store generated reports as `docs/CONTEXT_RESULTS_*.md` to maintain an auditable history.

## Commit & Pull Request Guidelines
Use Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`). PRs should explain intent, link issues (e.g., `Closes #123`), and include screenshots or logs when tooling changes behavior. Verify the stack with `./scripts/compose.ps1 up` and rerun relevant sweeps before requesting review.

## Security & Configuration Tips
Never commit secrets; sync `.env` with `.env.example`. The compose stack pins `ollama/ollama:0.3.14`, `ghcr.io/open-webui/open-webui:v0.3.7`, and `qdrant/qdrant:v1.15.4`; validate new images in a branch before updating. Keep large artifacts in `data/` or `models/`, and export backups prior to pruning containers.
