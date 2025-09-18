# Local AI Infrastructure (Cloud-Independent, OSS)

This repository scaffolds a local, open-source AI stack using Docker Compose. It runs fully on your machine with no cloud dependency.

## Prerequisites
- Windows 11 (WSL2 optional), admin rights
- Docker Desktop (with "Use the WSL 2 based engine" enabled)
- Git

Optional: Python 3.10+, Node.js LTS, PowerShell 7 for scripts.

## Quickstart
1. Initialize the workspace: `./scripts/bootstrap.ps1 -PromptSecrets` (creates `.env`, `data/`, and `models/`, and lets you confirm CLI keys interactively). Running `./scripts/bootstrap.ps1` without switches now opens an interactive menu so you can trigger health checks and benchmarks from one place.
2. Adjust `.env` if you need different ports or storage paths. Benchmark defaults (model, prompt, evidence directory) are stored in `.env` under the *Diagnostics and benchmarking* section. The template also seeds `LOG_FILE=./logs/stack.log` so compose and script logs consolidate under `./logs/`.
3. Start the stack: `./scripts/compose.ps1 up` (PowerShell).
4. Open WebUI: http://localhost:3000 (connects to local Ollama at http://localhost:11434).

GPU hosts should layer the GPU overlay when starting the stack directly with Docker Compose: `docker compose -f infra/compose/docker-compose.yml -f infra/compose/docker-compose.gpu.yml up -d`. The base file now defaults Ollama to CPU mode so CI and non-NVIDIA machines can boot the stack without errors; the overlay re-enables CUDA by requesting GPU resources and restoring the NVIDIA environment variables while pinning visibility to GPU index 1 (sized for the RTX 3060).

For automation pipelines that must avoid prompts, call `./scripts/bootstrap.ps1 -NoMenu` to skip the interactive menu once provisioning is complete.

## Validation & Health Checks
- Generate a host environment fingerprint with `./scripts/bootstrap.ps1 -Report` (writes `docs/ENVIRONMENT.md` **and** archives the same output under `docs/evidence/environment/`). The report now checks for `curl`, `pytest`, `nvidia-smi`, and `ollama` in addition to the original tooling list.
- Launch the interactive diagnostics menu explicitly with `./scripts/bootstrap.ps1 -Menu`. The menu exposes GPU evaluation, host checks, and the imported Clean repository utilities.
- Run a guarded evaluation sweep with GPU validation: `./scripts/context-sweep.ps1 -Safe -WriteReport` (add `-CpuOnly` only when CUDA resources are unavailable to keep evidence flowing into `docs/CONTEXT_RESULTS_*.md`).
- Run local pre-commit checks before pushing: `./scripts/precommit.ps1 -Mode quick` (add `-InstallPythonDeps -InstallPester` on first run). Use `./scripts/precommit.ps1 -Mode full -Gpu` for parity with CI when GPUs are available.
- Install a Git hook that enforces the quick gate automatically via `./scripts/hooks/install-precommit.ps1` (pass `-Mode full` or `-Gpu` to customize).
- Tail combined service logs: `./scripts/compose.ps1 logs`.
- Run automated smoke tests locally with `pip install -r requirements/python/dev.txt && pytest`. These checks parse `infra/compose/docker-compose.yml`, verify Modelfiles, and validate `.env.example` defaults. The same suite executes in CI via `.github/workflows/smoke-tests.yml`.
- If PowerShell is unavailable, run `pytest tests/test_powershell_metadata.py` to mirror the lightweight Pester assertions against the helper scripts.
- GitHub Actions boots the stack with the CPU override compose file (`infra/compose/docker-compose.ci.yml`), runs Pester, records a plan-only context sweep (the Ollama weights stay local to avoid multi-gigabyte downloads), and captures host state for reproducible evidence.

The compose stack is pinned to `ollama/ollama:0.3.14`, `ghcr.io/open-webui/open-webui:v0.3.7`, and `qdrant/qdrant:v1.15.4`. Update the tags in `infra/compose/docker-compose.yml` after validating new releases.

## Diagnostics & Evidence
- GPU evaluation and host health snapshots initiated from the bootstrap menu are saved in timestamped folders under `docs/evidence/`.
- `scripts/clean/capture_state.ps1` mirrors the Clean repository tooling: it captures `nvidia-smi` summaries, Ollama inventory, and optional Docker metadata to `docs/evidence/state/<timestamp>/`.
- `scripts/clean/prune_evidence.ps1` prunes old snapshots from `docs/evidence/state/`, keeping the newest runs (default 5) or directories younger than the `-MaxAgeDays` threshold so evidence rotation can run unattended.
- `scripts/clean/bench_ollama.ps1` runs repeatable latency and throughput measurements against the model defined in `.env` (default `llama3.1:8b`) using the prompt stored at `docs/prompts/bench-default.txt`. Results land in `docs/evidence/benchmarks/` as Markdown + JSON artifacts.
- To change evidence destinations, adjust `EVIDENCE_ROOT` inside `.env`; all diagnostics respect this path.

## Codex CLI Integration
- The Codex CLI expects an API key even when proxying to local Ollama. `./scripts/bootstrap.ps1` ensures `.env` contains `OLLAMA_API_KEY=ollama-local`; rerun with `-PromptSecrets` or edit `.env` to change it.
- Export `OLLAMA_API_KEY` from `.env` before invoking the CLI so requests succeed without breaking automation flows.
- The bootstrap script also warns when the `codex` executable or other optional dependencies (e.g., `curl`) are missing, highlighting prerequisites before you start compose operations.

## Components
- Ollama (`ollama/ollama:0.3.14`): Local LLM runtime and model manager
- Open WebUI (`ghcr.io/open-webui/open-webui:v0.3.7`): Web interface for chat and orchestration
- Qdrant (`qdrant/qdrant:v1.15.4`): Vector database for embeddings/RAG

See `docs/ARCHITECTURE.md` for details.

## Development
- Edit compose config in `infra/compose/docker-compose.yml`.
- Place persistent data under `data/` and models under `models/` (git-ignored).
- Restore tooling via the matrices listed in `requirements/README.md` to keep local installs aligned with CI.
- Update environment report via `./scripts/bootstrap.ps1 -Report` and read `docs/ENVIRONMENT.md`.

## Documentation & Reports
- `docs/PROJECT_REPORT_2025-09-16.md`: Full operational and risk report covering stack status, tooling, and recommendations.
- `docs/ARCHITECTURE.md`: High-level service layout and networking overview.
- `docs/RELEASE_v2025-09-16.md`: Latest release notes and operational checklist.
- `docs/CONTEXT_RESULTS_*.md`: Historical context sweep outcomes.
- `docs/STACK_STATUS_2025-09-16.md`: Snapshot of available tooling, outstanding gaps, and next validation actions.
- `docs/ENVIRONMENT.md`: Generated host environment fingerprint (regenerate after host changes).
- `docs/RELEASE_AUDIT_2025-09-18.md`: Current release readiness audit summarising automation, documentation, and evidence gaps.
- `docs/FULL_STACK_AUDIT_2025-09-19.md`: Latest CI and dependency audit capturing the plan-only sweep change and tooling convergence.
- `docs/TASK_TEST_HARDENING_PROMPT_2025-09-18.md`: Actionable brief to close testing gaps before declaring release readiness.
### GPU targeting
- The GPU-tuned Modelfile now defaults to `main_gpu 1` so RTX 3060 hosts target the second adapter without manual edits.
- Override the GPU index when needed: `./scripts/model.ps1 create -Model llama31-8b-gpu -MainGpu 0` or `./scripts/model.ps1 create-all -MainGpu 2` to target other adapters.
- Context variants ignore the override, but the helper script applies it when the GPU profile is built.

### Context sweeps
- `./scripts/context-sweep.ps1` now accepts `-Profile` or honours `CONTEXT_SWEEP_PROFILE` from `.env` to switch between long-context (`llama31-long`), balanced (`qwen3-balanced`), and CPU baselines.
- Each profile pins `num_gpu=1` to avoid dual-GPU brownouts; safe mode further trims token targets for 32k runs.
- Use the new `-PlanOnly` switch in ephemeral CI to validate the sweep plan without downloading multi-gigabyte Ollama weights.
- See `docs/CONTEXT_PROFILES.md` for guidance on alternative Ollama models (llama3.2:3b-instruct, phi3.5:mini, mistral-nemo) and how to register custom profiles.






