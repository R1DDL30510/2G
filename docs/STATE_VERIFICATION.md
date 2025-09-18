# State Verification Checklist

This document tracks the current stability of the stack and the checks that keep it reproducible.

## Stable Today
- **Infrastructure compose files** – `infra/compose/docker-compose.yml` (CPU baseline) and `infra/compose/docker-compose.ci.yml` (CI overrides) run with the repository `.env` and resolve storage paths automatically.
- **Helper tooling** – `scripts/compose.ps1` now forwards `--env-file` and accepts optional overlays via `-File`, enforcing non-zero exit codes from Docker.
- **Core services** – Ollama, Open WebUI, and Qdrant start cleanly on Docker Desktop / Engine without GPU access.
- **Python guardrails** – `pytest` validates compose manifests, `.env.example`, and Modelfiles without network access.

## Experimental or Host-Dependent
- **GPU overlay** – `infra/compose/docker-compose.gpu.yml` is optional and depends on NVIDIA container support. Treat failures as host-specific until validated on real hardware.
- **Context sweeps** – `./scripts/context-sweep.ps1` supports plan-only runs in CI. Full sweeps still require local model downloads and sufficient VRAM.
- **PowerShell-only tooling** – the richer diagnostics (capture-state, benchmarking) need PowerShell 7 and may not run on minimal shells.

## Verification Steps
Run these checks after changing infrastructure, scripts, or documentation referenced by the stack:

```powershell
# Python smoke tests
python -m pip install -r requirements/python/dev.txt
pytest

# Optional PowerShell mirror
pwsh -File tests/pester/scripts.Tests.ps1

# Optional context sweep (plan only keeps CI lightweight)
./scripts/context-sweep.ps1 -Safe -CpuOnly -PlanOnly -WriteReport
```

Record the outcomes in `docs/evidence/` when promoting a change to ensure reviewers can audit the run.
