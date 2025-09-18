# Infrastructure Status - 2025-09-16

## Current Stack Overview
- Docker Compose orchestrates Ollama, Open WebUI, and Qdrant with pinned container images for reproducible local deployments (see `infra/compose/docker-compose.yml`).
- `scripts/bootstrap.ps1` prepares `.env`, ensures data/model directories exist, emits environment diagnostics, and now enforces the new `CONTEXT_SWEEP_PROFILE` default alongside evidence directory provisioning.
- `.env.example` mirrors runtime defaults and ships placeholder values while highlighting required overrides; `.env` is generated via bootstrap with benchmarking, sweep, and evidence keys populated.
- Custom Modelfiles cover long-context variants and a GPU profile; `scripts/model.ps1 create-all -MainGpu <index>` provisions every target from `modelfiles/` via the running container.

## Available Tooling
| Area | Status | Reference |
|------|--------|-----------|
| Compose lifecycle | PowerShell wrapper handles `up`, `down`, `restart`, and `logs`; layer `docker-compose.gpu.yml` for CUDA runs while CI consumes `docker-compose.ci.yml` to force CPU mode. | `scripts/compose.ps1`, `infra/compose/docker-compose.gpu.yml`, `infra/compose/docker-compose.ci.yml` |
| Model management | `scripts/model.ps1` covers listing/pulling/creating models inside the container, with `-MainGpu` overrides for the GPU Modelfile. | `scripts/model.ps1` |
| Evaluation | `scripts/context-sweep.ps1` + `scripts/eval-context.ps1` support profile-driven sweeps (`llama31-long`, `qwen3-balanced`, `cpu-baseline`), safe mode throttling, CPU-only runs, and Markdown reports. | `scripts/context-sweep.ps1`, `scripts/eval-context.ps1`, `docs/CONTEXT_PROFILES.md` |
| Benchmarking & evidence | Benchmarks now run through `docker exec` (`scripts/clean/bench_ollama.ps1`); `scripts/clean/capture_state.ps1` snapshots host telemetry. CI persists outputs under `docs/evidence/`. | `scripts/clean/bench_ollama.ps1`, `scripts/clean/capture_state.ps1` |
| Automated tests | Pytest smoke tests cover env/compose/modelfiles; Pester suite asserts script parameters and profile wiring. | `tests/`, `tests/pester/` |
| Documentation | Architecture, release notes, context results, environment fingerprints, and profile guidance live under `docs/`. | `docs/ARCHITECTURE.md`, `docs/RELEASE_v2025-09-16.md`, `docs/CONTEXT_RESULTS_*`, `docs/ENVIRONMENT.md`, `docs/CONTEXT_PROFILES.md` |

## Validation (Current Session)
- `./scripts/bootstrap.ps1 -PromptSecrets -Report` executed successfully, yielding updated `.env`, `docs/ENVIRONMENT.md`, and `docs/evidence/environment/environment-report-*.md`.
- `python -m pytest` passes (13 tests), confirming `.env.example`, compose manifest heuristics, and Modelfiles.
- Pester tests could not be run locally (`Invoke-Pester` unavailable in Windows PowerShell 5.1), but CI installs Pester 5 and executes the suite on `ubuntu-latest`.
- Context sweep profiles exercise CPU-safe paths; GPU validation remains pending in this session.

## Outstanding Gaps and Risks
- GPU-enabled sweeps and benchmarks are still pending; CI exercises the CPU-baseline profile only.
- PowerShell 7+ is recommended for local Pester runs; Windows PowerShell 5.1 lacks `Install-Module`/`Invoke-Pester`, so operators should provision modern PowerShell before relying on the new tests.
- Image pins remain static; monitor upstream releases for security patches.
- Multi-GPU hosts must still validate `-MainGpu` overrides in `scripts/model.ps1` before production rollout.

## Action Checklist for Operators
1. Run `./scripts/bootstrap.ps1 -PromptSecrets` to generate `.env`, confirm dependency warnings, and capture the latest environment report.
2. Start the stack with `./scripts/compose.ps1 up` (or `docker compose -f infra/compose/docker-compose.yml up -d`) and verify service health (`curl` Ollama, Open WebUI, and Qdrant endpoints).
3. Provision models: `./scripts/model.ps1 create-all -MainGpu <index>` followed by `./scripts/model.ps1 list`; archive the output for evidence.
4. Execute `./scripts/context-sweep.ps1 -Safe -Profile llama31-long -WriteReport` on a CUDA-capable host; for thermal-sensitive runs, switch to `qwen3-balanced` or `cpu-baseline`. Store results under `docs/evidence/`.
5. Capture telemetry with `./scripts/clean/capture_state.ps1 -OutputRoot docs/evidence/ci` and run `./scripts/clean/bench_ollama.ps1` to benchmark latency through the containerised Ollama runtime.
6. Before merging, run Pytest locally and ensure CI greenlights pytest, Pester, context sweeps, and health probes.
