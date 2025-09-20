# Local AI Stack (Modular Core)

This repository ships a minimal Docker Compose stack for running a single Ollama instance. The PowerShell helpers keep the interface consistent across platforms, while the stack stays intentionally small so you can layer extra services only when they are required.

## Prerequisites
- Windows 11, macOS, or Linux with Docker Engine/Desktop
- PowerShell 7 (`pwsh`) for the helper scripts
- Python 3.11 for the validation suite
- Optional: Node.js LTS if you work with the Codex CLI utilities

## Quickstart
1. **Bootstrap the workspace** – `./scripts/bootstrap.ps1 -PromptSecrets` seeds `.env`, ensures the `models/` folder exists, and runs the basic host checks.
2. **Review `.env`** – copy `.env.example` if the file is missing and adjust the documented knobs (`REGISTRY_NAMESPACE`, `STACK_IMAGE_TAG`, `OLLAMA_VISIBLE_GPUS`, `WEBUI_AUTH`, etc.) to match your registry, hardware, and authentication needs. The compose helper resolves relative paths against the repository root automatically.
3. **Start the stack** – `./scripts/compose.ps1 up` brings up the Ollama service using the repository `.env`. Add overlays with `-File` when experimenting:
   ```powershell
   ./scripts/compose.ps1 up -File docker-compose.gpu.yml
   ```
   Use `down`, `restart`, or `logs` for the other lifecycle operations.
4. **Interact with Ollama** – the API is available at `http://localhost:11434` by default. Use `./scripts/model.ps1` to list, pull, or create models inside the container.

## Configuration
- `.env` controls the runtime image (`OLLAMA_IMAGE`), listening port (`OLLAMA_PORT`), storage paths, and diagnostics defaults. Use `.env.example` as the canonical template—it enumerates registry overrides (`REGISTRY_NAMESPACE`, `STACK_IMAGE_TAG`), GPU toggles (`OLLAMA_VISIBLE_GPUS`, `OLLAMA_GPU_ALLOCATION`, `OLLAMA_USE_CPU`), and OpenWebUI authentication options (`WEBUI_AUTH`). If `.env` is missing the compose helper falls back to the template but exits early when neither exists so CI can flag the configuration error.
- `infra/compose/docker-compose.yml` defines the single-service baseline. Images are intentionally unpinned and can be overridden via environment variables to keep deployments modular.
- `infra/compose/docker-compose.gpu.yml` adds GPU scheduling hints for the Ollama container; layer it only on hosts with CUDA-capable hardware.
- `modelfiles/baseline.Modelfile` is the curated default. Extend the folder with additional Modelfiles when experimenting with alternative prompts or parameters.

## GPU acceleration
The stack runs in CPU mode by default. On hosts with NVIDIA GPUs and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed, flip the runtime switches in `.env` and layer the GPU override without editing the baseline compose file:

```powershell
# PowerShell helper keeps `.env` in sync
./scripts/compose.ps1 up -File docker-compose.gpu.yml
```

Or from any shell:

```bash
docker compose --env-file .env \
  -f infra/compose/docker-compose.yml \
  -f infra/compose/docker-compose.gpu.yml up -d
```

Set `OLLAMA_USE_CPU=false` to instruct the container to prefer GPUs, `OLLAMA_VISIBLE_GPUS` to target a subset (`0`, `0,1`, or `all`), and `OLLAMA_GPU_ALLOCATION` to change the Compose `gpus:` hint (`all`, `1`, etc.). Use `docker compose down` with the same files when tearing the stack down.

## Services
| Service | Image | Notes |
|---------|-------|-------|
| `ollama` | `${OLLAMA_IMAGE:-ollama/ollama}` | CPU by default; enable GPU scheduling with the optional overlay. |

## State Verification
The `docs/STATE_VERIFICATION.md` checklist summarises what is stable today and what remains experimental. Review it after changes to confirm the following guardrails stay green:
- `pytest` – validates the compose manifest, `.env.example`, and Modelfiles without contacting external services.
- `./scripts/validate-stack.sh` – launches the compose stack with the current `.env` overrides, waits for the Ollama health endpoint, and tears everything down. CI runs it after building the local images to catch runtime regressions before publishing.
- `pwsh -File tests/pester/scripts.Tests.ps1` – mirrors the PowerShell metadata checks for contributors without Python.
- `./scripts/context-sweep.ps1 -Safe -CpuOnly -PlanOnly -WriteReport` – optional plan-only sweep to confirm the diagnostics pipeline still runs without large model downloads.

## Continuous Integration
Two GitHub Actions workflows keep the stack reproducible:
- **syntax-check.yml** sets up Python, compiles the test tree, and runs the fast pytest suite. It also parses all PowerShell scripts for syntax errors.
- **smoke-tests.yml** installs Python tooling, hydrates `.env` from the example template, runs pytest and Pester, boots the minimal compose stack with CPU overrides, waits for the Ollama health endpoint, records a plan-only context sweep, and captures the host state snapshot. A follow-up `validate-stack` job reuses the runner's Docker daemon (and any images built earlier in the pipeline) to run `./scripts/validate-stack.sh`, failing the workflow if the stack cannot start or respond.

## Development Notes
- Use `./scripts/model.ps1 create-all` to recreate every Modelfile inside the running Ollama container.
- Evidence and benchmark outputs land in `docs/evidence/` according to the paths from `.env`.
- Keep tests under `tests/` mirrored with their implementation counterparts to stay aligned with the repository structure described in `AGENTS.md`.

For a quick situational overview, start with `docs/STATE_VERIFICATION.md` and the latest entries under `docs/evidence/`.
