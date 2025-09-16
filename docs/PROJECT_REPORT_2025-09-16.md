# Full Project Report – Local AI Infrastructure

## Executive Summary
- The repository provisions a self-contained, Docker Compose based AI stack that runs Ollama, Open WebUI, and Qdrant entirely on local hardware with no cloud dependencies.
- PowerShell automation scripts cover bootstrap, compose lifecycle, model lifecycle, and evaluation flows, but automated quality gates remain minimal and still rely on manual verification.
- Recent context sweeps executed in safe mode validated CPU-only runs up to 12k tokens; GPU validation and higher context targets remain outstanding follow-up work.
- Key risks center on absent test coverage, limited observability, and manual coordination of GPU resources; prioritized actions focus on enabling GPU sweeps, adding smoke tests, and hardening backup and monitoring practices.

## Stack Snapshot

### Service Inventory
| Service | Container Image | Purpose | Persistent Data |
|---------|-----------------|---------|-----------------|
| Ollama | `ollama/ollama:0.3.14` | Hosts local LLMs, exposes generate API on `11434/tcp`. | `models/` cache plus read-only `modelfiles/` for custom variants. |
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.3.7` | Browser-based chat UI that proxies to Ollama. | `data/open-webui/` for settings and history. |
| Qdrant | `qdrant/qdrant:v1.15.4` | Vector database backing RAG workflows. | `data/qdrant/` volume for collections. |

### Orchestration & Configuration
- `infra/compose/docker-compose.yml` pins the stack to the images above, enables GPU access for Ollama (`gpus: all`, `NVIDIA_VISIBLE_DEVICES=all`), and forwards default ports via `.env` overrides.【F:infra/compose/docker-compose.yml†L1-L33】
- Environment defaults ship in `.env.example`; `scripts/bootstrap.ps1` copies them into `.env` and prepares `data/` and `models/` directories on first run.【F:.env.example†L1-L11】【F:scripts/bootstrap.ps1†L1-L44】
- Persistent assets are git-ignored to keep the repository lightweight while preserving local state between compose cycles.

### Model Assets
- Custom context-window variants (`llama31-8b-c4k`, `c8k`, `c16k`, `c32k`) and a GPU-tuned profile are defined under `modelfiles/` as thin wrappers around `llama3.1:8b` with adjusted parameters.【F:modelfiles/llama31-8b-c8k.Modelfile†L1-L3】
- `scripts/model.ps1` orchestrates listing, pulling, creating, and running models directly inside the Ollama container, ensuring Modelfile-based variants stay synchronized.【F:scripts/model.ps1†L1-L61】

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
- **Testing Coverage:** No unit or integration test suites exist yet; quality relies on manual compose smoke checks and context sweeps. Introduce pytest/jest scaffolding mirroring future `src/` additions to reduce regression risk.
- **Operational Visibility:** Compose logs (`scripts/compose.ps1 logs`) provide baseline observability. Augment with container health checks, GPU telemetry (e.g., `nvidia-smi` sampling), and Qdrant snapshot verification procedures.
- **Reliability Risks:** Manual GPU toggling, absence of automated sweeps, and missing backup routines for `data/` volumes represent the highest operational risks. Document and automate volume backup/restore flows prior to significant usage.
- **Security & Compliance:** Secrets are not committed; `.env` stays local. Continue reviewing upstream image CVEs before bumping tags and enforce local auth (`OPENWEBUI_AUTH=true`) when exposing beyond localhost.

## Recommended Actions (Prioritized)
1. Execute a GPU-enabled context sweep (`./scripts/context-sweep.ps1 -Safe -WriteReport`) and archive the results to validate CUDA paths end-to-end.
2. Stand up minimal automated smoke tests (e.g., PowerShell Pester scripts for compose lifecycle and API reachability) to catch configuration regressions early.
3. Build a lightweight backup job for `data/open-webui` and `data/qdrant` directories, documenting restore drills in `docs/`.
4. Expand `docs/ARCHITECTURE.md` with deployment diagrams and sequence flows to aid onboarding, and link telemetry/monitoring conventions.
5. Schedule periodic reviews of pinned container images, capturing change logs and security notes in future release reports.

## Reference Materials
- Quickstart instructions and stack prerequisites live in `README.md` and `README-G1MvP.md`.
- Detailed release notes: `docs/RELEASE_v2025-09-16.md` (current stable baseline).
- Automation scripts: see `scripts/` folder for compose, model, bootstrap, and evaluation helpers.
- Latest environment fingerprint: `docs/ENVIRONMENT.md` (regenerate after host upgrades).
