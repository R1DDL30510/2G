# Full Stack Audit – 2025-09-20

## Executive Summary
- GitHub-hosted runners were unable to execute the PowerShell automation that wraps Docker Compose because multiple scripts hard-coded the Windows-style path `infra\compose\docker-compose.yml`. On Linux this string is treated as a literal backslash and the compose file cannot be found, so commands such as `docker compose -f infra\compose\docker-compose.yml config` fail and short-circuit the bootstrap and benchmarking flows that the CI menu relies on.【F:scripts/compose.ps1†L1-L33】【F:scripts/bootstrap.ps1†L323-L356】【F:scripts/clean/bench_ollama.ps1†L1-L52】
- Central dependency manifests remain aligned: both workflows still install Python tooling from `requirements/python/ci.txt`, which reuses the shared base list documented under `requirements/README.md`, and no drift between local and CI environments was observed.【F:requirements/README.md†L1-L16】【F:.github/workflows/smoke-tests.yml†L20-L47】【F:.github/workflows/syntax-check.yml†L16-L27】

## CI Workflow Health Check
- `syntax-check.yml` continues to gate bytecode compilation and the fast pytest suite using Python 3.11. No workflow changes were required beyond verifying the dependency pin still resolves against the shared requirement files.【F:.github/workflows/syntax-check.yml†L1-L31】【F:requirements/python/base.txt†L1-L2】
- `smoke-tests.yml` provisions the stack, performs HTTP probes, and captures a plan-only context sweep so runners do not need to download Ollama weights. The workflow now benefits from the path fixes because any invocation of `scripts/bootstrap.ps1`, `scripts/clean/bench_ollama.ps1`, or similar helpers would otherwise fail when executed on Linux agents.【F:.github/workflows/smoke-tests.yml†L20-L47】【F:scripts/clean/capture_state.ps1†L1-L77】

## Remediation Details
- Replaced the Windows-specific `Join-Path ... 'infra\compose\docker-compose.yml'` pattern with `[System.IO.Path]::Combine` in every automation entry point (`scripts/compose.ps1`, `scripts/bootstrap.ps1`, `scripts/clean/bench_ollama.ps1`, and `scripts/clean/capture_state.ps1`). This guarantees the compose manifest resolves on both Windows and Linux runners, restoring CI parity.【F:scripts/compose.ps1†L1-L33】【F:scripts/bootstrap.ps1†L331-L349】【F:scripts/clean/bench_ollama.ps1†L1-L52】【F:scripts/clean/capture_state.ps1†L1-L86】
- Added a regression test to `tests/test_powershell_metadata.py` that fails if `infra\compose` reappears in any of the critical scripts, so future contributors cannot reintroduce Windows-only paths unnoticed.【F:tests/test_powershell_metadata.py†L1-L54】
- Updated `docs/NEXT_STEPS.md` to reference the portable compose path so operational runbooks no longer suggest the Windows-specific form.【F:docs/NEXT_STEPS.md†L1-L5】

## Validation
- Python smoke suite: `pytest` covering config, compose, Modelfiles, and PowerShell metadata (includes the new path guard).【7ae7c1†L1-L12】
- Bytecode compilation: `python -m compileall tests` to mirror the syntax check workflow.【4f21b9†L1-L5】

## Outstanding Follow-Ups
- Consider adding a lightweight CI smoke step that exercises `scripts/bootstrap.ps1 -Report` on Linux runners now that the path issue is resolved; this would catch future regressions in the bootstrap menu.
- Monitor the Docker bring-up duration in CI. If containers begin taking longer than the current three-minute polling window, extend the retry count in `scripts/wait_for_http.py` invocations to keep the pipeline stable.
