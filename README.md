# Local AI Stack (Modular Core)

The repository packages a single-service Ollama stack that favours clarity over breadth. Every component is modular: add overlays or extra services only when you are ready, otherwise the baseline stays lightweight and easy to reason about.

## Snapshot of the stack

| Area | Status | Notes |
| --- | --- | --- |
| Compose baseline | ✅ Stable | `infra/compose/docker-compose.yml` starts one Ollama container with CPU defaults. No images are pinned so tags stay modular. |
| Helper scripts | ✅ Stable | PowerShell entrypoints in `scripts/` wrap Docker and model actions while surfacing errors consistently. |
| GPU overlay | ⚠️ Experimental | `infra/compose/docker-compose.gpu.yml` assumes NVIDIA-capable hosts; keep it optional. |
| Context sweep | ⚠️ Host-dependent | `scripts/context-sweep.ps1` supports plan-only runs everywhere, but full sweeps depend on local resources. |
| Additional services | 🧩 Modular | Layer new compose files under `infra/compose/` and ship matching tests before promoting them. |

See `docs/STATE_VERIFICATION.md` for the canonical checklist and current guardrail results.

## Dependencies at a glance

- **Host prerequisites** – Docker Engine/Desktop, PowerShell 7 (`pwsh`), and Python 3.11. Node.js LTS is only required when using the optional CLI helpers.
- **Environment configuration** – `.env.example` documents the runtime variables. Copy it to `.env` (or run `./scripts/bootstrap.ps1 -PromptSecrets`) before starting the stack.
- **Python tooling** – all requirements are centralised under `requirements/python/`. Install `requirements/python/dev.txt` locally; CI pulls from the same base list via `requirements/python/ci.txt`.

The folder `requirements/README.md` lists every dependency surface, including PowerShell and Node.js guidance, so the workflows and documentation stay in sync.

## Quickstart
1. **Bootstrap** – `./scripts/bootstrap.ps1 -PromptSecrets` ensures `.env` exists, creates `models/`, and runs basic host checks.
2. **Review configuration** – tweak `OLLAMA_IMAGE`, `OLLAMA_PORT`, or `MODELS_DIR` in `.env`. The compose helper resolves relative paths against the repository root automatically.
3. **Start the baseline** – `./scripts/compose.ps1 up` launches the Ollama container with CPU defaults. Append `-File docker-compose.gpu.yml` only when you intentionally opt into the GPU overlay.
4. **Work with models** – the API lives at `http://localhost:11434`. Use `./scripts/model.ps1` to list, pull, or create the curated `modelfiles/baseline.Modelfile` inside the container.

## Verification loop

Run these guardrails after changing infrastructure, scripts, or modelfiles:

```powershell
python -m pip install -r requirements/python/dev.txt
pytest

pwsh -File tests/pester/scripts.Tests.ps1

./scripts/context-sweep.ps1 -Safe -CpuOnly -PlanOnly -WriteReport  # optional, plan-only
```

Record results in `docs/evidence/` when relevant. The workflows in `.github/workflows/` mirror the same sequence so CI stays aligned with local practice.

## Service catalogue

| Service | Default image | Purpose |
| --- | --- | --- |
| `ollama` | `${OLLAMA_IMAGE:-ollama/ollama}` | Minimal runtime exposing the Ollama HTTP API with CPU-safe defaults. |

Future services belong in separate compose overlays and should include matching tests before merging. Keep the baseline focused on the single Ollama workload.
