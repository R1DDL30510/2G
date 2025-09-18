# Full Stack Audit – 19 September 2025

## Executive Summary
- The compose stack (Ollama, Open WebUI, Qdrant) remains pinned and declarative; CPU-first defaults let automation run without GPU access while optional overlays restore CUDA for targeted hosts.【F:infra/compose/docker-compose.yml†L1-L33】【F:infra/compose/docker-compose.gpu.yml†L1-L6】
- CI workflows now install tooling from a central requirements index and execute context sweeps in plan-only mode, eliminating the transient GitHub runner failures that occurred when Ollama weights were missing.【F:requirements/README.md†L1-L16】【F:.github/workflows/smoke-tests.yml†L20-L47】
- Local developers share the same Python dependency set via `requirements/python/dev.txt`, keeping pytest checks aligned with the GitHub Actions gate.【F:requirements/python/dev.txt†L1-L2】

## CI Diagnostics
- `scripts/context-sweep.ps1` evaluates Ollama profiles such as the CPU baseline (`llama3.1:8b`) and long-context variants, which require models to exist inside the container.【F:scripts/context-sweep.ps1†L72-L119】【F:scripts/context-sweep.ps1†L199-L236】
- On clean GitHub runners the models were absent, so the sweep attempted to hit the generate API before any weights had been pulled, causing repeated HTTP 404 failures and red pipelines.
- A new `-PlanOnly` switch records the execution plan without issuing network calls, allowing CI to validate configuration while highlighting that real inference still depends on local model provisioning.【F:scripts/context-sweep.ps1†L1-L37】【F:scripts/context-sweep.ps1†L138-L236】
- The smoke-test workflow consumes the switch (`./scripts/context-sweep.ps1 -Safe -CpuOnly -Profile cpu-baseline -PlanOnly -WriteReport`), ensuring pipeline stability without masking the requirement for explicit model creation during manual validation.【F:.github/workflows/smoke-tests.yml†L20-L47】

## Dependency Posture
- All Python dependency definitions now live under `requirements/`, with CI and developer installs referencing the same base list to prevent drift.【F:requirements/README.md†L1-L16】【F:requirements/python/base.txt†L1-L2】
- The legacy `requirements-dev.txt` file is retained as a thin wrapper that points to the new layout so existing scripts and documentation continue to work.【F:requirements-dev.txt†L1-L2】
- README guidance was updated to steer contributors towards the central index and to document the plan-only CI sweep behaviour.【F:README.md†L22-L51】

## Verification
- Python smoke tests: `pytest` covering compose manifests, `.env` defaults, Modelfiles, and PowerShell metadata.【954c59†L1-L11】
- Python bytecode compilation: `python -m compileall tests` (matches CI syntax check).【f8b986†L1-L9】
- PowerShell Pester tests are executed in CI; local runs still require PowerShell Core, which is unavailable in this container.

## Recommendations
- Keep an internal cache of approved Ollama weights to enable full `context-sweep` runs outside CI and attach fresh evidence to `docs/CONTEXT_RESULTS_*.md` before releases.
- Extend the PowerShell metadata tests to cover the new `-PlanOnly` switch to guard against regressions when the sweep tooling evolves.
- Consider adding lightweight contract tests for `scripts/model.ps1` once PowerShell is available cross-platform to validate Docker interactions after future refactors.
