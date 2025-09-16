# Infrastructure Status – 2025-09-16

## Current Stack Overview
- Docker Compose orchestrates Ollama, Open WebUI, and Qdrant with pinned container images for reproducible local deployments (see `infra/compose/docker-compose.yml`).
- `scripts/bootstrap.ps1` prepares `.env`, ensures data/model directories exist, verifies CLI dependencies, and now injects a default `OLLAMA_API_KEY` placeholder for Codex CLI workflows.
- `.env.example` mirrors the runtime defaults and ships the new CLI placeholder so non-interactive setups inherit a safe dummy key.
- Custom Modelfiles for multiple llama3.1 context sizes remain available for on-demand creation inside the Ollama container.

## Available Tooling
| Area | Status | Reference |
|------|--------|-----------|
| Compose lifecycle | PowerShell wrapper handles `up`, `down`, `restart`, and `logs` around the pinned compose file. | `scripts/compose.ps1` |
| Model management | `scripts/model.ps1` covers listing, pulling, creating, and running Ollama models directly in the container. | `scripts/model.ps1` |
| Evaluation | `scripts/context-sweep.ps1` + `scripts/eval-context.ps1` plan deterministic recall tests with optional CPU-only and reporting modes. | `scripts/context-sweep.ps1`, `scripts/eval-context.ps1` |
| Documentation | Architecture, release notes, historical sweep outputs, and environment fingerprints remain under `docs/`. | `docs/ARCHITECTURE.md`, `docs/PROJECT_REPORT_2025-09-16.md`, `docs/CONTEXT_RESULTS_*`, `docs/RELEASE_v2025-09-16.md`, `docs/ENVIRONMENT.md` |

## Validation (Current Session)
- PowerShell (`pwsh`) is unavailable inside this container, so automation scripts could not be executed here; run them on a host with PowerShell 7+ installed.
- Docker is also missing, preventing compose smoke tests inside this environment; execute stack bring-up on a machine with Docker Desktop or Docker Engine installed.
- No containers were started in this session to keep the workspace consistent; follow the action checklist below on your target host.

## Outstanding Gaps and Risks
- GPU-enabled context sweeps are still pending; prior reports only covered CPU-safe runs and should be extended before production workloads.
- Automated smoke tests remain absent; future work should add Pester/pytest coverage to guard compose and API regressions.
- Ensure codex CLI availability on operators' machines so the new bootstrap warnings remain actionable.

## Action Checklist for Operators
1. Run `./scripts/bootstrap.ps1 -PromptSecrets` to generate `.env`, confirm the `OLLAMA_API_KEY` value, and review dependency warnings.
2. Export the resulting `OLLAMA_API_KEY` (dummy or custom) before launching the Codex CLI so requests authenticate cleanly.
3. Start the stack with `./scripts/compose.ps1 up` and verify service health via `./scripts/compose.ps1 logs`.
4. Register custom context variants with `./scripts/model.ps1 create-all` after the Ollama container is online.
5. Execute `./scripts/context-sweep.ps1 -Safe -CpuOnly -WriteReport` to capture a fresh baseline, then repeat without `-CpuOnly` when GPU resources are ready.
