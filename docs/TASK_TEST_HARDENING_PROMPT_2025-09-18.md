# Task Prompt – Testing Hardening for Release Readiness (2025-09-18)

## Objective
Deliver a comprehensive testing upgrade that elevates the infrastructure stack to an industrial-grade, release-ready posture with measurable coverage, GPU validation, and automated evidence capture.

## Context
- Current automation focuses on structural smoke checks (pytest + Pester) and CPU-only validation; runtime inference and GPU sweeps remain manual or absent.【F:docs/COVERAGE_REPORT_2025-09-17.md†L1-L48】【F:docs/STACK_STATUS_2025-09-16.md†L25-L44】
- The `smoke-tests` GitHub Actions workflow already provisions the stack, probes endpoints, runs a CPU context sweep, and archives telemetry, providing a base pipeline to extend.【F:.github/workflows/smoke-tests.yml†L1-L56】
- Roadmap items call for broader coverage instrumentation and CI enforcement but are not yet implemented.【F:roadmap/testing-expansion.md†L1-L13】

## Deliverables
1. GPU-enabled validation pathway executed in CI that provisions the GPU Modelfile, runs a CUDA-backed context sweep, and uploads the resulting Markdown/JSON artifacts to `docs/evidence/`.
2. Runtime health checks that verify inference success (e.g., invoking the Ollama HTTP API with a sample prompt) and persistence integrity for Open WebUI and Qdrant volumes.
3. Coverage instrumentation for both pytest and Pester with thresholds enforced in CI and published reports stored under `docs/evidence/coverage/`.
4. Documentation updates (README, release notes, or new runbooks) describing how to trigger the expanded tests locally and interpret coverage artifacts.

## Acceptance Criteria
- [ ] CI matrix includes GPU-enabled job(s) with guards to skip gracefully when hardware is unavailable, while still running CPU coverage.
- [ ] `pytest` suite exercises runtime behaviour (compose bring-up, API probes, artifact generation) and emits coverage ≥80% for targeted modules.
- [ ] Pester suite covers bootstrap menu flows, context sweep parameterization, and benchmarking helpers with coverage ≥80%.
- [ ] Successful pipeline publishes Markdown/HTML coverage reports and context sweep outputs into `docs/evidence/coverage/` and `docs/evidence/context/` (or similar) with timestamps.
- [ ] Release checklist (README or dedicated doc) enumerates the automated gates and links to the latest evidence bundles.

## Suggested Implementation Steps
1. Extend the GitHub Actions workflow with a conditional GPU job that leverages `scripts/model.ps1` and `scripts/context-sweep.ps1` to run CUDA sweeps; surface outputs via `actions/upload-artifact`.
2. Introduce pytest fixtures that bring the compose stack up in-process, perform API assertions against Ollama, Open WebUI, and Qdrant, then tear down after tests to keep runs isolated.
3. Build out Pester tests covering CLI switches, error paths, and logging/reporting logic within the PowerShell scripts (`bootstrap.ps1`, `context-sweep.ps1`, `clean/*`).
4. Integrate coverage tooling: `pytest --cov=... --cov-report=html,xml` and `Invoke-Pester -CodeCoverage ...` with post-processing steps that copy artifacts into `docs/evidence/coverage/` and add them to the PR diff.
5. Update documentation and the release checklist to reflect the new automation, including instructions for interpreting coverage dashboards and scheduling regular evidence refreshes.

## Risks & Dependencies
- GPU runners may be unavailable in standard CI; plan for self-hosted runners or document fallback CPU procedures.
- Coverage tooling could increase pipeline duration; budget for caching, selective test targets, or nightly full runs.
- Ensure secrets and environment variables required for inference remain stubbed or mocked to keep the pipeline deterministic.

## Definition of Done
- Pull request(s) implementing the above deliverables merge with all new checks passing, coverage artifacts committed (or published via artifacts), and documentation updated to mirror the strengthened release gates.
