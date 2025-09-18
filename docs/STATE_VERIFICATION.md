# State Verification Checklist

This checklist highlights the current stability of the minimal stack and the guardrails that keep it reproducible. Images and dependencies remain intentionally unpinned so overlays can evolve without fragmenting the base workflow.

## Status Snapshot

| Component | Status | Notes |
|-----------|--------|-------|
| Compose manifest | ✅ Stable | `infra/compose/docker-compose.yml` starts a single Ollama service and honours `OLLAMA_IMAGE`, `OLLAMA_PORT`, and `MODELS_DIR` overrides from `.env`. |
| Bootstrap & directories | ✅ Stable | `scripts/bootstrap.ps1` seeds `.env`, provisions the `MODELS_DIR`, evidence root, and the parent of `LOG_FILE`, and confirms helper dependencies. |
| Baseline Modelfile | ✅ Stable | `modelfiles/baseline.Modelfile` wraps `llama3.1` with conservative CPU defaults while forwarding the prompt template unchanged. |
| Python guardrails | ✅ Stable | `pytest` validates the compose manifest, `.env.example`, and Modelfiles without contacting external services. |
| GPU overlay | ⚠️ Host-dependent | `infra/compose/docker-compose.gpu.yml` expects NVIDIA container support and should be treated as experimental until validated on real hardware. |
| Context sweeps | ⚠️ Host-dependent | `./scripts/context-sweep.ps1` offers plan-only runs in CI; full executions still require local model downloads and sufficient CPU/GPU capacity. |
| Additional overlays | ⚠️ Host-dependent | Any service layered on top of the minimal stack must ship its own verification steps to remain modular. |

## Stable Today
- **Compose manifest** – `infra/compose/docker-compose.yml` starts a single Ollama container and honours runtime overrides from `.env`.
- **Helper scripts** – `scripts/bootstrap.ps1`, `scripts/compose.ps1`, and `scripts/model.ps1 create-all` operate cross-platform, create the directories referenced by `MODELS_DIR`, `EVIDENCE_ROOT`, and `LOG_FILE`, and surface non-zero exit codes when Docker or PowerShell fail.
- **Baseline Modelfile** – `modelfiles/baseline.Modelfile` wraps `llama3.1` with conservative CPU defaults and passes the template through unchanged.
- **Python guardrails** – `pytest` validates the compose manifest, `.env.example`, and Modelfiles without contacting external services.

## Experimental or Host-Dependent
- **GPU overlay** – `infra/compose/docker-compose.gpu.yml` depends on NVIDIA container support. Treat failures as host-specific until validated on real hardware.
- **Context sweeps** – `./scripts/context-sweep.ps1` supports plan-only runs in CI. Full executions still require local model downloads and sufficient CPU/GPU capacity.
- **Additional services** – any service layered on top of the minimal stack must ship its own verification steps.

## Compose overlays in practice
The baseline remains a single Ollama service. When you need to expand, add a focused overlay file under `infra/compose/` so the extra workload stays optional. For example, to introduce a vector store without bloating the default manifest:

```yaml
# infra/compose/docker-compose.qdrant.yml
services:
  qdrant:
    image: qdrant/qdrant
    restart: unless-stopped
    ports:
      - "6333:6333"
```

Start it alongside the baseline only when required:

```powershell
./scripts/compose.ps1 up -File docker-compose.qdrant.yml
```

Ship complementary guardrails (pytest or Pester checks) with any new overlay so CI can detect drift early.

## Verification Steps
Run these checks after changing infrastructure, scripts, or documentation referenced by the stack:

```powershell
# Python smoke tests
python -m pip install -r requirements/python/dev.txt
pytest

# Optional PowerShell mirror
pwsh -File tests/pester/scripts.Tests.ps1

# Optional context sweep (plan-only keeps CI lightweight)
./scripts/context-sweep.ps1 -Safe -CpuOnly -PlanOnly -WriteReport
```

Record outcomes in `docs/evidence/` when promoting a change so reviewers can audit the run.
