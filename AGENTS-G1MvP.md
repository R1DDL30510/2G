Repository Guidelines
=====================

This quick reference captures the current conventions. Review it before making substantial changes or opening a pull request.

## Project Structure & Module Organization

```
├─ infra/compose/        # Docker Compose orchestration
│  └─ docker-compose.yml # Minimal Ollama runtime
├─ scripts/              # PowerShell helpers (compose, bootstrap, models, diagnostics)
├─ modelfiles/           # Custom Ollama Modelfiles
├─ models/               # Persistent model cache (ignored by git)
├─ src/                  # Application code (mirror layout in tests/)
├─ tests/                # Python + Pester guardrails
└─ docs/                 # Focused documentation (see STATE_VERIFICATION.md)
```

Keep the implementation and test trees aligned. New modules in `src/` should have peers under `tests/`.

## Build, Test, and Development Commands

- `./scripts/bootstrap.ps1 -PromptSecrets` – ensure `.env` exists and confirm host prerequisites.
- `./scripts/compose.ps1 up|down|restart|logs` – manage the lightweight Ollama stack.
- `./scripts/model.ps1 create-all` – create the curated Modelfiles inside the running container.
- `docker compose -f infra/compose/docker-compose.yml up -d` – shell-agnostic launch of the minimal stack.
- `pip install -r requirements/python/dev.txt && pytest` – run the cross-platform smoke tests used in CI.

All helper scripts are PowerShell; prefer them over raw Docker commands unless automating a bespoke flow.

## Coding Style & Naming Conventions

* `.editorconfig` enforces 2 spaces for JS/TS, JSON, YAML, Markdown; 4 spaces for Python and PowerShell.
* Filenames: JS/TS use kebab-case, Python uses snake_case, PowerShell cmdlets use PascalCase.
* Run language-appropriate formatters and linters before committing.

## Testing Guidelines

* Python guardrails rely on `pytest` and run offline.
* PowerShell parity checks live under `tests/pester` and mirror the Python assertions for contributors without Python.
* Optional end-to-end diagnostics: `./scripts/context-sweep.ps1 -Safe -CpuOnly -WriteReport` once the minimal stack is online.

## Commit & Pull Request Guidelines

* Follow Conventional Commit prefixes (`feat:`, `fix:`, `docs:`, `chore:`).
* Clearly describe intent, reference related issues, and include logs or screenshots when behaviour changes.
* Ensure `./scripts/compose.ps1 up` and the Python test suite succeed before requesting review.

## Security & Configuration Tips

* Do **not** commit secrets. Align `.env` with `.env.example` via `./scripts/bootstrap.ps1 -PromptSecrets`.
* Container images are configurable via environment variables; tags are intentionally left flexible for modular deployments.
* Persist large artefacts under `models/` and back them up before pruning.

Use these guidelines to keep the project focused, reproducible, and easy to extend.

