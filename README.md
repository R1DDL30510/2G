# Local AI Stack (Modular Core)

This repository ships a minimal Docker Compose stack for running a single Ollama instance. The PowerShell helpers keep the interface consistent across platforms, while the stack stays intentionally small so you can layer extra services only when they are required.

## Prerequisites
- Windows 11, macOS, or Linux with Docker Engine/Desktop
- PowerShell 7 (`pwsh`) for the helper scripts
- Python 3.11 for the validation suite
- Optional: Node.js LTS if you work with the Codex CLI utilities

## Quickstart
1. **Bootstrap the workspace** – `./scripts/bootstrap.ps1 -PromptSecrets` seeds `.env`, provisions the directories referenced by `MODELS_DIR`, `EVIDENCE_ROOT`, and `LOG_FILE`, and runs the basic host checks.
2. **Review `.env`** – adjust `OLLAMA_IMAGE`, `OLLAMA_PORT`, or `MODELS_DIR` as required. The compose helper resolves relative paths against the repository root automatically.
3. **Start the stack** – `./scripts/compose.ps1 up` brings up the Ollama service using the repository `.env`. Add overlays with `-File` when experimenting:
   ```powershell
   ./scripts/compose.ps1 up -File docker-compose.gpu.yml
   ```
   Use `down`, `restart`, or `logs` for the other lifecycle operations.
4. **Interact with Ollama** – the API is available at `http://localhost:11434` by default. Use `./scripts/model.ps1` to list, pull, or create models inside the container.

## Configuration
- `.env` controls the runtime image (`OLLAMA_IMAGE`), listening port (`OLLAMA_PORT`), storage paths, and diagnostics defaults. If the file is missing the compose helper falls back to `.env.example` but exits early when neither exists so CI can flag the configuration error.
- `infra/compose/docker-compose.yml` defines the single-service baseline. Images are intentionally unpinned and can be overridden via environment variables to keep deployments modular.
- `infra/compose/docker-compose.gpu.yml` adds GPU scheduling hints for the Ollama container; layer it only on hosts with CUDA-capable hardware.
- `modelfiles/baseline.Modelfile` is the curated default. Extend the folder with additional Modelfiles when experimenting with alternative prompts or parameters.

## Services
| Service | Image | Notes |
|---------|-------|-------|
| `ollama` | `${OLLAMA_IMAGE:-ollama/ollama}` | CPU by default; enable GPU scheduling with the optional overlay. |

## State Verification
The `docs/STATE_VERIFICATION.md` checklist summarises what is stable today and what remains experimental. Review it after changes to confirm the following guardrails stay green:
- `pytest` – validates the compose manifest, `.env.example`, and Modelfiles without contacting external services.
- `pwsh -File tests/pester/scripts.Tests.ps1` – mirrors the PowerShell metadata checks for contributors without Python.
- `./scripts/context-sweep.ps1 -Safe -CpuOnly -PlanOnly -WriteReport` – optional plan-only sweep to confirm the diagnostics pipeline still runs without large model downloads.

## Continuous Integration
Two GitHub Actions workflows keep the stack reproducible:
- **syntax-check.yml** sets up Python, compiles the test tree, and runs the fast pytest suite. It also parses all PowerShell scripts for syntax errors.
- **smoke-tests.yml** installs Python tooling, hydrates `.env` from the example template, runs pytest and Pester, boots the minimal compose stack with CPU overrides, waits for the Ollama health endpoint, records a plan-only context sweep, and captures the host state snapshot.

## Development Notes
- Use `./scripts/model.ps1 create-all` to recreate every Modelfile inside the running Ollama container.
- Evidence and benchmark outputs land in `docs/evidence/` according to the paths from `.env`.
- Keep tests under `tests/` mirrored with their implementation counterparts to stay aligned with the repository structure described in `AGENTS.md`.

For a quick situational overview, start with `docs/STATE_VERIFICATION.md` and the latest entries under `docs/evidence/`.
