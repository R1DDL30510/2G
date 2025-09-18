# Full Project Report – Local AI Infrastructure

## Executive Summary
- The repository provisions a self-contained Docker Compose stack (Ollama, Open WebUI, Qdrant) with PowerShell automation, but it ships only scaffolding—model weights, evidence artifacts, and persistent data remain operator-supplied.
- Structural smoke tests exist, yet runtime assurances still depend on manual verification; GPU validation, telemetry capture, and coverage publishing have not occurred.
- Context sweeps executed in safe CPU mode reached 12k tokens, while the advertised GPU profile lacks automation support, leaving a mismatch between documented inventory and available scripts.
- Key risks include missing GPU evidence, empty `docs/evidence/` directories, minimal automated testing, and manual backup/observability processes that must be formalised before production rollout.

## Stack Snapshot

### Service Inventory
| Service | Container Image | Purpose | Persistent Data |
|---------|-----------------|---------|-----------------|
| Ollama | `ollama/ollama:0.3.14` | Hosts local LLMs, exposes generate API on `11434/tcp`. | `models/` cache plus read-only `modelfiles/` for custom variants. |
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.3.7` | Browser-based chat UI that proxies to Ollama. | `data/open-webui/` for settings and history. |
| Qdrant | `qdrant/qdrant:v1.15.4` | Vector database backing RAG workflows. | `data/qdrant/` volume for collections. |

### Orchestration & Configuration
- `infra/compose/docker-compose.yml` pins the stack to the images above, forwards default ports via `.env` overrides, and now defaults Ollama to CPU mode for portability; `infra/compose/docker-compose.gpu.yml` layers NVIDIA variables and a GPU request when CUDA hardware is available.【F:infra/compose/docker-compose.yml†L1-L33】【F:infra/compose/docker-compose.gpu.yml†L1-L6】
- Environment defaults ship in `.env.example`; `scripts/bootstrap.ps1` copies them into `.env` and prepares `data/` and `models/` directories on first run.【F:.env.example†L1-L11】【F:scripts/bootstrap.ps1†L1-L44】
- Persistent assets are git-ignored to keep the repository lightweight while preserving local state between compose cycles.

### Model Assets
- Custom context-window variants (`llama31-8b-c4k`, `c8k`, `c16k`, `c32k`) and a GPU-tuned profile are defined under `modelfiles/` as thin wrappers around `llama3.1:8b` with adjusted parameters.【F:modelfiles/llama31-8b-c8k.Modelfile†L1-L3】
- `scripts/model.ps1` orchestrates listing, pulling, creating, and running models directly inside the Ollama container, ensuring Modelfile-based variants stay synchronized.【F:scripts/model.ps1†L1-L61】
- **Automation gap:** `scripts/model.ps1 create-all` covers only the context variants, so the GPU profile documented in reports must be created manually, creating an inventory vs. automation inconsistency.

## Operational Tooling & Automation

### PowerShell Automation Surface
- `scripts/compose.ps1` accepts `up`, `down`, `restart`, and `logs` verbs, wrapping the compose file path logic so operators avoid manual directory management.【F:scripts/compose.ps1†L1-L24】
- `scripts/bootstrap.ps1 -Report` emits `docs/ENVIRONMENT.md` with host OS, architecture, and CLI tool detection, supporting reproducibility audits; without `-Report`, it bootstraps `.env`, `data/`, and `models/` folders.【F:scripts/bootstrap.ps1†L1-L44】
- `scripts/context-sweep.ps1` plans multi-model evaluation runs, optionally CPU-only or safe-mode throttled, and can persist Markdown summaries under `docs/` via `-WriteReport`.【F:scripts/context-sweep.ps1†L1-L58】【F:scripts/context-sweep.ps1†L60-L84】
- `scripts/eval-context.ps1` powers the sweep by generating deterministic retrieval-style prompts, issuing Ollama API calls, and reporting recall accuracy and latency per model.【F:scripts/eval-context.ps1†L1-L64】

### Context Evaluation Status
- Safe CPU sweeps at `2025-09-16_15-05-26` and `2025-09-16_15-17-49` verified token targets up to 12k using the `llama31-8b-c{4k,8k,16k,32k}` variants; the earlier run showed a single failure at the largest window, while the follow-up passed all entries, both with ~30–40s latency budgets.【F:docs/CONTEXT_RESULTS_2025-09-16_15-05-26.md†L1-L9】【F:docs/CONTEXT_RESULTS_2025-09-16_15-17-49.md†L1-L9】
- No GPU-enabled sweep has been captured yet; removing the `-CpuOnly` flag is the next validation gate to confirm CUDA utilization end-to-end.

### Environment Baseline
- The latest `docs/ENVIRONMENT.md` capture shows Windows 11 Pro for Workstations with PowerShell 5.1; core tooling (Docker, Git, Python, Node) was not detected at generation time, signaling that the report was produced before installing those dependencies on that host.【F:docs/ENVIRONMENT.md†L1-L13】
- Before production use, regenerate the report after verifying Docker Desktop, Git, and runtime toolchains are installed and aligned with organizational standards.

## Quality, Risk, and Observability
- **Testing Coverage:** Structural pytest checks exist but provide no runtime confidence; compose bring-up, API reachability, and PowerShell script behaviour remain untested.
- **Operational Visibility:** Compose logs (`scripts/compose.ps1 logs`) are the only routine insight today. GPU telemetry, `nvidia-smi` capture, and evidence exports to `docs/evidence/` have not been established.
- **Reliability Risks:** Manual GPU toggling, lack of automated sweeps, empty backup procedures for `data/` volumes, and the `create-all`/GPU profile mismatch are the current blockers.
- **Security & Compliance:** Secrets are still excluded from version control; maintain diligence around pinned image CVEs and enable `OPENWEBUI_AUTH=true` before exposing services beyond localhost.

## Recommended Actions (Prioritized)
1. Update `scripts/model.ps1 create-all` (or document the manual step) so the GPU profile can be recreated alongside the context variants, resolving the inventory mismatch.
2. Execute and automate GPU-enabled context sweeps (`./scripts/context-sweep.ps1 -Safe -WriteReport`) with artifacts published to `docs/evidence/` for traceability.
3. Expand automated coverage with runtime pytest probes and Pester suites, wiring results into CI and persisting coverage outputs.
4. Build and document repeatable backup/restore workflows for `data/open-webui` and `data/qdrant`, including telemetry guidance for GPU and container health.
5. Regenerate `docs/ENVIRONMENT.md` after verifying dependencies on an operator host and continue reviewing pinned container image CVEs in future release reports.

## Reference Materials
- Quickstart instructions and stack prerequisites live in `README.md` and `README-G1MvP.md`.
- Detailed release notes: `docs/RELEASE_v2025-09-16.md` (current stable baseline).
- Automation scripts: see `scripts/` folder for compose, model, bootstrap, and evaluation helpers.
- Latest environment fingerprint: `docs/ENVIRONMENT.md` (regenerate after host upgrades).
