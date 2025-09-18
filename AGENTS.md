# Repository Guidelines

## Project Structure & Module Organization
- Compose manifests live under `infra/compose/`; the baseline `docker-compose.yml` starts a single Ollama container. Layer extra services with additional files when required.
- PowerShell helpers in `scripts/` (for example `compose.ps1`, `model.ps1`, and `context-sweep.ps1`) manage lifecycle operations, diagnostics, and automated checks.
- Custom Ollama `Modelfile` definitions live in `modelfiles/`; persistent model weights stay under the configurable `${MODELS_DIR}` (ignored by git).
- Keep documentation focused on the minimal stack in `docs/`; surface verification status inside `docs/STATE_VERIFICATION.md`.
- Mirror implementation modules in `src/` with corresponding coverage under `tests/`.

## Build, Test, and Development Commands
- `./scripts/bootstrap.ps1 -PromptSecrets` seeds `.env` and confirms shell dependencies.
- `./scripts/compose.ps1 up|down|restart|logs` wraps Docker Compose while forwarding the repository `.env` automatically.
- `docker compose -f infra/compose/docker-compose.yml up -d` runs the lightweight stack from any shell.
- `./scripts/model.ps1 create-all` provisions the curated Modelfiles inside the running Ollama container.
- `pip install -r requirements/python/dev.txt && pytest` executes the Python guardrails used locally and in CI.

## Coding Style & Naming Conventions
- `.editorconfig` enforces 2 spaces for JavaScript, TypeScript, JSON, YAML, and Markdown; 4 spaces for Python and PowerShell.
- Use kebab-case filenames for JS/TS, snake_case for Python, and PascalCase for PowerShell cmdlets.
- Run language-specific formatters or linters before committing and keep module structure mirrored between `src/` and `tests/`.

## Testing Guidelines
- Place unit tests under `tests/` beside their implementation peers and stub external integrations.
- Keep test runs offline and deterministic; capture new fixtures under `tests/fixtures/` when necessary.
- Use `./scripts/context-sweep.ps1 -Safe -CpuOnly -WriteReport` for optional end-to-end diagnostics once the minimal stack is healthy.

## Commit & Pull Request Guidelines
- Use Conventional Commit prefixes such as `feat:`, `fix:`, and `chore:` with clear scopes.
- Reference related work (`Closes #123`), summarise behaviour changes, and attach logs or screenshots when output shifts.
- Verify `./scripts/compose.ps1 up` succeeds locally before requesting review.

## Security & Configuration Tips
- Never commit secrets; sync `.env` with `.env.example` using `./scripts/bootstrap.ps1 -PromptSecrets` when credentials change.
- Images are configurable via environment variables and intentionally unpinned—validate updates on a branch before promoting them.
- Store large artefacts in `models/` and prune volumes only after exporting backups when necessary.
