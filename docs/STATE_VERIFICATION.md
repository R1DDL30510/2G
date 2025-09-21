# State Verification Checklist

This checklist highlights the current stability of the minimal stack and the checks that keep it reproducible.

## Stable Today
- **Compose manifest** – `infra/compose/docker-compose.yml` starts a single Ollama container and honours `OLLAMA_IMAGE`, `OLLAMA_PORT`, and `MODELS_DIR` overrides from `.env`.
- **Helper scripts** – `scripts/bootstrap.ps1`, `scripts/compose.ps1`, and `scripts/model.ps1 create-all` operate cross-platform and surface non-zero exit codes when Docker or PowerShell fail.
- **Baseline Modelfile** – `modelfiles/baseline.Modelfile` wraps `llama3.1` with conservative CPU defaults and passes the template through unchanged.
- **Python guardrails** – `pytest` validates the compose manifest, `.env.example`, and Modelfiles without contacting external services.

## Experimental or Host-Dependent
- **GPU overlay** – `infra/compose/docker-compose.gpu.yml` depends on NVIDIA container support. Treat failures as host-specific until validated on real hardware.
- **Open WebUI overlay** – `infra/compose/docker-compose.openwebui.yml` couples a UI container to the Ollama API. It expects Ollama to stay reachable on the same Docker network (default bridge) and inherits GPU behaviour from the host.
- **Automatic1111 DirectML overlay** – `infra/compose/docker-compose.automatic1111.directml.yml` targets AMD GPUs via DirectML. Set `SD_WEBUI_IMAGE` to a compatible image and validate locally before promoting changes.
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

Ship complementary guardrails (pytest or Pester checks) with any new overlay so CI can detect drift early. `tests/infra/test_docker_compose.py` now validates the Ollama, Open WebUI, and Automatic1111 overlays at parse time.

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
