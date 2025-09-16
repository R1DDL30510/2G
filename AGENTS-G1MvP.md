Repository Guidelines
=====================

This document summarizes the conventions and workflows that the project follows.  Use it as a quick reference before you start coding or submitting a pull request.

## Project Structure & Module Organization

```
├─ infra/compose/        # Docker‑Compose orchestration
│  └─ docker-compose.yml
├─ scripts/              # PowerShell helpers (up, down, model pull, etc.)
├─ modelfiles/           # Custom Ollama Modelfiles
├─ data/                 # Persistent data (ignored by git)
├─ models/               # Model caches (ignored by git)
├─ src/                  # Application source (mirrors tests/ layout)
├─ tests/                # Unit tests, one folder per source module
└─ docs/                 # Documentation, reports, context sweeps
```

Maintain the `src/` and `tests/` tree in sync – for every new module in `src/`, create a corresponding test folder in `tests/`.

## Build, Test, and Development Commands

- `./scripts/compose.ps1 up` – spin up the full stack with the pinned `docker‑compose.yml`.
- `./scripts/compose.ps1 down` – tear down the stack.
- `./scripts/compose.ps1 logs` – view combined logs.
- `./scripts/model.ps1 pull –Model llama3.1:8b` – fetch and register a Modelfile model.
- `./scripts/context-sweep.ps1 –CpuOnly –Safe –WriteReport` – run a guarded end‑to‑end validation.
- `./scripts/context-sweep.ps1 –Gpu –WriteReport` – full GPU sweep (needs GPU availability).

All commands are PowerShell scripts; avoid invoking `docker compose` directly unless automating.

## Coding Style & Naming Conventions

*EditorConfig* sets 2‑space indentation for JS/TS, JSON, YAML, Markdown; 4‑space for Python, C#, PowerShell.
*File names*:
  - JS/TS: kebab‑case (e.g., `model-fetch.ts`).
  - Python: snake_case.
  - PowerShell: PascalCase.
*Cmdlet names*: `Get-Model`, `Invoke-ContextSweep`.
Run the linter/formatter for each language before committing (`npm run format`, `python -m black`, `pwsh .\scripts\format.ps1`).

## Testing Guidelines

Python tests use `pytest`; JS/TS tests use `jest`.  Tests mirror the source module layout and do **not** hit external services – mock or stub as required.
Run the full suite locally with:
```sh
python -m pytest tests/
jl run jest tests/
```
Coverage reports are output to `docs/` automatically by the context sweep.

## Commit & Pull Request Guidelines

Follow Conventional Commits:
```
feat: add new endpoint
fix: correct typo in README
docs: update usage example
chore: bump dependency
```
Pull requests must:
1. Describe the intent clearly.
2. Link any related issue (`Closes #45`).
3. Include logs or screenshots if a script or stack behaviour changes.
4. Pass `./scripts/compose.ps1 up` and at least one guarded context sweep before merge.

## Security & Configuration Tips

* Do **not** commit secrets.  Keep a local `.env` that matches `.env.example`.
* Large artefacts go in `data/` or `models/`; these folders are git‑ignored.
* Export container backups with the `qdrant‑backup.ps1` helper before pruning.
* Validate new Docker images on a dedicated branch before merging.
```ps1
./scripts/compose.ps1 pull -Image qdrant/qdrant:v1.16.0  # Example of a safe update
```

Use these guidelines to keep the project clean, testable, and secure.

