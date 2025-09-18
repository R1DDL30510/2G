# Stack Verification, Audit & Stabilization Plan – 2025-09-19

## Executive Summary
- Core compose services (Ollama, Open WebUI, Qdrant) and the PowerShell automation surface continue to operate on CPU-only hosts with reproducible bootstrap, model management, and evaluation entry points.【F:docs/PROJECT_REPORT_2025-09-16.md†L11-L35】【F:docs/STACK_STATUS_2025-09-16.md†L3-L17】
- Operators captured fresh CPU context sweeps, Ollama benchmark telemetry, and environment fingerprints, giving us a minimal evidence trail to confirm baseline health while highlighting GPU validation gaps.【F:docs/PROJECT_REPORT_2025-09-16.md†L36-L42】【F:docs/CONTEXT_RESULTS_2025-09-16_15-17-49.md†L1-L8】【F:docs/evidence/benchmarks/bench-test-20250917-185829/report.md†L1-L14】【F:docs/ENVIRONMENT.md†L1-L28】
- Release readiness remains blocked: coverage is structural only, GPU sweeps and benchmarks have not succeeded, and CI lacks measurable thresholds, so we must close those gaps before promoting another build.【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L52】【F:docs/RELEASE_AUDIT_2025-09-18.md†L68-L70】

## Status Snapshot
| Area | Status | Evidence | Notes |
|------|--------|----------|-------|
| Services & compose | ✅ Stable (CPU) | Compose pins the stack to known-good images and bootstrap keeps `.env`, `data/`, and `models/` aligned.【F:docs/PROJECT_REPORT_2025-09-16.md†L11-L21】 | GPU overlay exists but still depends on manual validation when CUDA hosts are available.【F:docs/PROJECT_REPORT_2025-09-16.md†L18-L38】 |
| Automation surface | ✅ Operational | PowerShell wrappers cover compose lifecycle, model workflows, context sweeps, telemetry capture, and evidence routing.【F:docs/STACK_STATUS_2025-09-16.md†L9-L17】【F:docs/RELEASE_AUDIT_2025-09-18.md†L17-L51】 | Keep using the scripted entry points to avoid drift between documentation and runtime behaviour.【F:docs/RELEASE_AUDIT_2025-09-18.md†L52-L55】 |
| Testing & CI | ⚠️ Partial | Local pytest run (13 tests) passes; Pester runs only in CI; `smoke-tests` workflow orchestrates compose bring-up, probes, and sweeps.【F:docs/STACK_STATUS_2025-09-16.md†L19-L23】【F:docs/RELEASE_AUDIT_2025-09-18.md†L23-L30】 | No runtime assertions for GPU paths or coverage thresholds yet.【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L26】 |
| Evidence trail | ⚠️ Partial | CPU sweeps, benchmark artifacts, and environment reports exist, but GPU evidence and successful benchmark iterations are missing.【F:docs/CONTEXT_RESULTS_2025-09-16_15-05-26.md†L1-L8】【F:docs/CONTEXT_RESULTS_2025-09-16_15-17-49.md†L1-L8】【F:docs/evidence/benchmarks/bench-test-20250917-185829/report.md†L1-L14】【F:docs/ENVIRONMENT.md†L1-L28】 | The recorded benchmark exited with code 125 and produced zero tokens, signalling setup work still pending.【F:docs/evidence/benchmarks/bench-test-20250917-185829/report.md†L5-L14】 |
| Coverage & release gate | ⛔ Blocked | Coverage analysis confirms runtime instrumentation is absent, evidence directories stay sparse, and release should remain blocked until GPU automation lands.【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L52】【F:docs/RELEASE_AUDIT_2025-09-18.md†L62-L70】 | Prioritize coverage automation before scheduling another readiness review.【F:roadmap/testing-expansion.md†L5-L13】 |

## Verification Evidence
### Services & orchestration
- Docker Compose pins Ollama, Open WebUI, and Qdrant while the GPU overlay reintroduces NVIDIA runtime variables when required.【F:docs/PROJECT_REPORT_2025-09-16.md†L11-L21】
- Bootstrap copies `.env.example`, prepares persistence folders, and keeps evidence directories consistent across hosts.【F:docs/PROJECT_REPORT_2025-09-16.md†L18-L21】

### Automation & operations
- Operators manage lifecycle and diagnostics exclusively through scripted entry points (`compose.ps1`, `bootstrap.ps1`, `context-sweep.ps1`, `model.ps1`, and `clean/*` helpers), ensuring repeatable flows.【F:docs/STACK_STATUS_2025-09-16.md†L9-L17】【F:docs/RELEASE_AUDIT_2025-09-18.md†L17-L51】
- Documentation across README, release notes, and dated reports stays synchronized with these scripts, giving historical traceability for audits.【F:docs/RELEASE_AUDIT_2025-09-18.md†L52-L55】

### Testing & continuous integration
- The latest validation window executed `python -m pytest` successfully (13 tests) and generated environment/evidence artifacts via bootstrap.【F:docs/STACK_STATUS_2025-09-16.md†L19-L21】
- CI complements local gaps: `smoke-tests` runs pytest, Pester, CPU compose bring-up, health probes, a safe context sweep, and telemetry capture on every push.【F:docs/RELEASE_AUDIT_2025-09-18.md†L23-L39】
- Pester remains unavailable on PowerShell 5.1 hosts; teams should install PowerShell 7+ to mirror CI coverage locally.【F:docs/STACK_STATUS_2025-09-16.md†L22-L28】

### Evidence & telemetry
- Two CPU safe-mode sweeps validated long-context variants up to 12k tokens; the first run flagged a 32k failure that was resolved in the follow-up.【F:docs/CONTEXT_RESULTS_2025-09-16_15-05-26.md†L1-L8】【F:docs/CONTEXT_RESULTS_2025-09-16_15-17-49.md†L1-L8】
- Ollama benchmarking captured latency metadata but ended with exit code 125 and zero tokens, indicating the harness or prompt still needs adjustment.【F:docs/evidence/benchmarks/bench-test-20250917-185829/report.md†L1-L14】
- Environment fingerprints now confirm both PowerShell 7.5.3 and CUDA-capable GPUs on the reference workstation; older captures still lacked several CLIs, so keep regenerating after upgrades.【F:docs/ENVIRONMENT.md†L1-L28】【F:docs/evidence/environment/environment-report-20250917-175532.md†L1-L27】

## Coverage & audit findings
- Structural smoke coverage protects compose manifests, Modelfiles, and `.env.example`, yet runtime coverage, GPU sweeps, and regression history remain absent, leaving effective coverage near zero.【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L33】
- Evidence directories stay sparse and benchmarks/reporting lack success criteria, so compliance, performance, and operational risks remain high until automation closes the loop.【F:docs/COVERAGE_REPORT_2025-09-17.md†L34-L52】【F:docs/RELEASE_AUDIT_2025-09-18.md†L29-L30】

## Gaps, risks, and issues
- GPU automation remains incomplete: sweeps run only in CPU mode and `scripts/model.ps1 create-all` omits the GPU profile, forcing manual intervention and leaving CUDA behaviour unverified.【F:docs/PROJECT_REPORT_2025-09-16.md†L26-L38】【F:docs/COVERAGE_REPORT_2025-09-17.md†L26-L33】
- Coverage instrumentation (`pytest --cov`, Pester CodeCoverage) is missing from CI, so we cannot prove behavioural stability or enforce regression gates.【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L52】【F:docs/RELEASE_AUDIT_2025-09-18.md†L62-L70】
- Benchmark harness currently returns exit code 125 with zero tokens, so latency metrics are inconclusive until we correct model selection, prompt wiring, or container health checks.【F:docs/evidence/benchmarks/bench-test-20250917-185829/report.md†L5-L14】
- Operator environments differ: the latest fingerprint is healthy, but earlier reports show missing CLIs (`pytest`, `pwsh`, `curl`), risking inconsistent validation if hosts are not standardized.【F:docs/ENVIRONMENT.md†L1-L28】【F:docs/evidence/environment/environment-report-20250917-175532.md†L11-L24】

## Enhancement & to-do plan
| Priority | Action | Target outcome |
|----------|--------|----------------|
| High | Automate GPU context sweeps and benchmarking in CI (remove `-CpuOnly`, ensure GPU profile is built) and publish resulting artifacts under `docs/evidence/`.【F:docs/PROJECT_REPORT_2025-09-16.md†L26-L38】【F:docs/COVERAGE_REPORT_2025-09-17.md†L26-L48】 | GPU evidence collected alongside CPU baselines for every validation window. |
| High | Add coverage instrumentation (pytest `--cov`, Pester CodeCoverage) per the testing expansion roadmap and fail CI when thresholds drop.【F:docs/COVERAGE_REPORT_2025-09-17.md†L3-L52】【F:roadmap/testing-expansion.md†L5-L13】 | Measurable coverage artifacts checked into `docs/evidence/coverage/` with enforced gates. |
| Medium | Extend `scripts/model.ps1 create-all` (or document the workaround) so GPU variants are reproducible without manual edits.【F:docs/PROJECT_REPORT_2025-09-16.md†L23-L27】 | Operators recreate the documented model inventory from a single command. |
| Medium | Harden benchmark harness (verify model availability, prompt path, and exit codes) so latency measurements finish successfully and capture throughput data.【F:docs/evidence/benchmarks/bench-test-20250917-185829/report.md†L5-L14】 | Benchmark artifacts include completed iterations with non-zero tokens/sec. |
| Medium | Standardize operator environment baselines: require PowerShell 7+, ensure core CLIs are present, and refresh fingerprints after changes.【F:docs/STACK_STATUS_2025-09-16.md†L22-L28】【F:docs/evidence/environment/environment-report-20250917-175532.md†L11-L24】 | Environment reports consistently show required tooling across all hosts. |

## Immediate operator actions
1. Run `./scripts/bootstrap.ps1 -PromptSecrets -Report` on the next validation host to refresh `.env`, diagnostics defaults, and environment fingerprints.【F:docs/STACK_STATUS_2025-09-16.md†L31-L35】
2. Bring up the stack with `./scripts/compose.ps1 up` (or the GPU overlay when available), then validate Ollama, Open WebUI, and Qdrant endpoints before proceeding.【F:docs/STACK_STATUS_2025-09-16.md†L32-L33】
3. Provision models via `./scripts/model.ps1 create-all -MainGpu <index>` followed by targeted GPU profile creation until the helper script is extended.【F:docs/STACK_STATUS_2025-09-16.md†L33-L35】【F:docs/PROJECT_REPORT_2025-09-16.md†L23-L27】
4. Execute `./scripts/context-sweep.ps1 -Safe -Profile llama31-long -WriteReport` and re-run benchmarks/telemetry capture so new evidence lands under `docs/evidence/`.【F:docs/STACK_STATUS_2025-09-16.md†L34-L36】【F:docs/RELEASE_AUDIT_2025-09-18.md†L29-L30】
