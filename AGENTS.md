# Repository Guidelines

## Project Structure & Module Organization
- Infrastructure in `infra/compose/` (Docker Compose). Docs in `docs/`. Scripts in `scripts/`. Data in `data/`, models in `models/` (both ignored by git).
- Add custom services under `src/` and mirror tests in `tests/`.

## Build, Test, and Development Commands
- Start/stop stack: `./scripts/compose.ps1 up|down|restart|logs`.
- Docker Compose direct: `docker compose -f infra/compose/docker-compose.yml up -d`.
- Optional stacks (Node/Python/.NET) live under `src/<service>/` with their own commands.

## Coding Style & Naming Conventions
- Use `.editorconfig` defaults: 2 spaces (JS/TS/YAML/MD), 4 spaces (PY/CS/PS1).
- Filenames: `kebab-case` for JS/TS, `snake_case` for Python.
- Run formatters/linters where configured before pushing.

## Testing Guidelines
- Place tests under `tests/` mirroring `src/`. Prefer unit tests; avoid network in unit scope.
- Aim for meaningful coverage; integration tests can target services via Compose.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Keep PRs small with clear descriptions and linked issues (e.g., `Closes #123`). Ensure CI (if added) passes.

## Security & Configuration Tips
- Do not commit secrets. Use `.env` (local only) and keep `.env.example` updated.
- Pin image tags/versions where stability matters.

