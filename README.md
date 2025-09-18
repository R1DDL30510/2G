# Local AI Stack (Modular Core)

This repository maintains a lean Docker Compose stack for experimenting with a single Ollama runtime plus the optional Open WebUI frontend and Qdrant vector store. The PowerShell helpers keep the footprint small while still allowing you to layer extra services as required.

## Prerequisites
- Windows 11, macOS, or Linux with Docker Engine/Desktop
- PowerShell 7 (`pwsh`) for the helper scripts
- Python 3.11 for the validation suite
- Optional: Node.js LTS if you work with the Codex CLI utilities

## Quickstart
1. **Bootstrap the workspace** – `./scripts/bootstrap.ps1 -PromptSecrets` seeds `.env`, creates data/model folders, and runs the basic host checks.
2. **Review `.env`** – adjust the exposed ports or storage locations. The compose helper now resolves these paths before calling Docker so relative values such as `./data` resolve to the repository root automatically.
3. **Start the stack** – `./scripts/compose.ps1 up` brings up Ollama, Open WebUI, and Qdrant using the repository `.env`. Add overlays with `-File` when required:
   ```powershell
   ./scripts/compose.ps1 up -File docker-compose.gpu.yml
   ```
   Use `down`, `restart`, or `logs` for the other lifecycle operations.
4. **Open the interfaces** – Ollama listens on `http://localhost:11434`, Open WebUI on `http://localhost:3000`, and Qdrant on `http://localhost:6333` by default.

## Configuration
- `.env` controls ports, storage paths, authentication flags, and diagnostics defaults. If the file is missing the compose script falls back to `.env.example` but exits early when neither exists so CI can detect misconfigurations immediately.
- `infra/compose/docker-compose.yml` defines the minimal three-service stack. Paths rely on `${MODELS_DIR}` and `${DATA_DIR}` so overrides stay declarative.
- `infra/compose/docker-compose.gpu.yml` adds GPU scheduling hints for the single Ollama container; layer it only on hosts with CUDA-capable hardware.
- `modelfiles/` contains the curated Ollama variants. The automation only assumes the base llama3.1:8b lineage, so you can remove or add profiles without touching the compose layout.

## Services
| Service    | Image                                   | Notes |
|------------|-----------------------------------------|-------|
| `ollama`   | `ollama/ollama:0.3.11`                  | CPU by default; enable GPU with the overlay. |
| `open-webui` | `ghcr.io/open-webui/open-webui:v0.6.30` | Depends on `ollama`; stores state under `${DATA_DIR}/open-webui`. |
| `qdrant`   | `qdrant/qdrant:v1.15.4`                 | Persists collections under `${DATA_DIR}/qdrant`. |

All images remain pinned so updates require an explicit PR, keeping reproducibility intact even while the rest of the stack stays modular.

## State Verification
The `docs/STATE_VERIFICATION.md` checklist summarises what is stable today and what remains experimental. Regenerate or review it after changes to confirm the following guardrails stay green:
- `pytest` – validates compose manifests, `.env.example`, and Modelfiles without contacting external services.
- `pwsh -File tests/pester/scripts.Tests.ps1` – mirrors the metadata checks for contributors without Python.
- `./scripts/context-sweep.ps1 -Safe -CpuOnly -PlanOnly -WriteReport` – optional plan-only sweep to ensure evidence capture still works without large model downloads.

## Continuous Integration
Two GitHub Actions workflows keep the stack reproducible:
- **syntax-check.yml** sets up Python, compiles the test tree, and runs the fast pytest suite. It also parses all PowerShell scripts for syntax errors.
- **smoke-tests.yml** installs Python tooling, creates a `.env` from the example template, runs pytest and Pester, boots the compose stack with the CPU override, waits for health endpoints, records a plan-only context sweep, and captures the host state snapshot. The helper now passes `--env-file` automatically so overrides defined in the repository take effect during CI runs.

## Development Notes
- Use `./scripts/model.ps1` to list, pull, or create Modelfiles inside the running Ollama container.
- Evidence and benchmark outputs land in `docs/evidence/` according to the paths from `.env`.
- Keep tests under `tests/` mirrored with their implementation counterparts to stay aligned with the repository structure described in `AGENTS.md`.

For a quick situational overview, start with `docs/STATE_VERIFICATION.md` and the latest entries under `docs/evidence/`.
