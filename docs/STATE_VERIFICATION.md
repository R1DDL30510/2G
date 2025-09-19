# State Verification Checklist

The table below captures the current health of the minimal stack. Update it whenever the underlying artefacts change so reviewers know what is battle-tested and what still needs attention.

| Area | Status | Notes |
| --- | --- | --- |
| Compose baseline | ✅ Stable | `infra/compose/docker-compose.yml` honours `.env` overrides for image, port, and storage. |
| Helper scripts | ✅ Stable | `scripts/bootstrap.ps1`, `scripts/compose.ps1`, and `scripts/model.ps1 create-all` exit non-zero on failure and run on Windows, macOS, and Linux. |
| Baseline Modelfile | ✅ Stable | `modelfiles/baseline.Modelfile` wraps `llama3.1` with CPU-safe defaults; no prompt mutation occurs. |
| Python guardrails | ✅ Stable | `pytest` checks the compose manifest, `.env.example`, and Modelfiles without needing network access. |
| GPU overlay | ⚠️ Experimental | `infra/compose/docker-compose.gpu.yml` assumes NVIDIA container support. Treat issues as host-specific until validated on hardware. |
| Context sweep | ⚠️ Host-dependent | `./scripts/context-sweep.ps1` passes in plan-only mode everywhere; full runs still rely on local model downloads and capacity. |
| Additional services | 🧩 Modular | Overlays under `infra/compose/` must remain optional and ship new guardrails before merging. |

## How to extend the stack safely

1. Create a dedicated compose overlay in `infra/compose/` for each extra service. Keeping overlays separate preserves the single-service default.
2. Add matching pytest or Pester checks so CI fails fast when the new component drifts.
3. Update this document with the new component’s status once the guardrails pass consistently.

## Verification steps to run

```powershell
python -m pip install -r requirements/python/dev.txt
pytest

pwsh -File tests/pester/scripts.Tests.ps1

./scripts/context-sweep.ps1 -Safe -CpuOnly -PlanOnly -WriteReport  # optional plan-only sweep
```

Record outcomes in `docs/evidence/` when promoting a change so reviewers can audit the run. Nothing in the stack is pinned: update images or dependencies deliberately and refresh the checklist afterwards.
