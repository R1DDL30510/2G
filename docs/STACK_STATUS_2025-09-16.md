# Infrastructure Status – 2025-09-16

## Current Stack Overview
- Docker Compose orchestrates Ollama, Open WebUI, and Qdrant with pinned container images for reproducible local deployments (see `infra/compose/docker-compose.yml`).
- `scripts/bootstrap.ps1` prepares `.env`, ensures data/model directories exist, emits environment diagnostics, and flags missing dependencies; the generated reports currently show Docker, Git, and Python absent on the captured host.
- `.env.example` mirrors runtime defaults and ships placeholder values, keeping secrets untracked while highlighting required overrides before exposing services externally.
- Custom Modelfiles cover long-context variants and a GPU profile, but only the context variants are automated through `scripts/model.ps1 create-all`, leaving the GPU profile as a manual step.

## Available Tooling
| Area | Status | Reference |
|------|--------|-----------|
| Compose lifecycle | PowerShell wrapper handles `up`, `down`, `restart`, and `logs` around the pinned compose file. | `scripts/compose.ps1` |
| Model management | `scripts/model.ps1` covers listing, pulling, creating, and running Ollama models directly in the container (GPU profile currently manual). | `scripts/model.ps1` |
| Evaluation | `scripts/context-sweep.ps1` + `scripts/eval-context.ps1` plan deterministic recall tests with optional CPU-only and reporting modes (only CPU evidence captured to date). | `scripts/context-sweep.ps1`, `scripts/eval-context.ps1` |
| Documentation & evidence | Architecture, release notes, historical sweep outputs, and environment fingerprints live under `docs/`; the `docs/evidence/` tree remains empty pending automation. | `docs/ARCHITECTURE.md`, `docs/PROJECT_REPORT_2025-09-16.md`, `docs/CONTEXT_RESULTS_*`, `docs/RELEASE_v2025-09-16.md`, `docs/ENVIRONMENT.md` |

## Validation (Current Session)
- PowerShell (`pwsh`) is unavailable inside this container, so automation scripts could not be executed here; run them on a host with PowerShell 7+ installed.
- Docker is also missing, preventing compose smoke tests inside this environment; execute stack bring-up on a machine with Docker Desktop or Docker Engine installed.
- No containers were started in this session to keep the workspace consistent; follow the action checklist below on your target host.

## Outstanding Gaps and Risks
- GPU-enabled context sweeps are still pending; prior reports only covered CPU-safe runs and `docs/evidence/` has no artifacts.
- `scripts/model.ps1 create-all` omits the GPU profile, so documentation and automation diverge until the script or docs are updated.
- Automated runtime smoke tests are absent; existing pytest checks assert structure only, and PowerShell automation is untested.
- Operator environments continue to miss prerequisites (PowerShell 7+, Docker, Git, Python), limiting reproducibility of the documented workflows.

## Action Checklist for Operators
1. Run `./scripts/bootstrap.ps1 -PromptSecrets` to generate `.env`, confirm dependency warnings, and regenerate `docs/ENVIRONMENT.md` from a fully provisioned host.
2. Start the stack with `./scripts/compose.ps1 up` and verify service health via `./scripts/compose.ps1 logs` before enabling external access.
3. Register custom context variants with `./scripts/model.ps1 create-all`, then create the `llama31-8b-gpu` profile manually until the automation gap is closed.
4. Execute `./scripts/context-sweep.ps1 -Safe -WriteReport` on a CUDA-capable host, ensuring artifacts are copied into `docs/evidence/`.
5. Integrate expanded pytest/Pester checks into CI and track coverage outputs alongside release documentation.
