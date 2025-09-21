# Multi-Host Architecture Overview

This document captures how the repository maps to the two-host deployment pattern discussed in the WSL2/Docker evaluation. It shows which overlays each host consumes, how shared assets flow between them, and where Docker contexts come into play.

## Goals
- Keep the **baseline Ollama stack** identical on every platform.
- Layer **optional services** (GPU, Open WebUI, Automatic1111) as compose overlays so hosts only run what they need.
- Manage **multiple Docker daemons** from one workstation via Docker contexts.

## Host Roles & Overlay Matrix
| Host | Purpose | Hardware | Required Compose files | Notes |
| --- | --- | --- | --- | --- |
| Host 1 – Windows 11 with WSL2 | Primary development box with NVIDIA GPU | RTX 2060 / 3060 | `docker-compose.yml`, `docker-compose.gpu.yml`, optional `docker-compose.openwebui.yml` | WSL2 backend enables NVIDIA passthrough for Ollama and Open WebUI.|
| Host 2 – Windows 11 (native) | Stable Diffusion experiments on AMD | Radeon RX6700XT | `docker-compose.yml`, optional `docker-compose.automatic1111.directml.yml` | Requires DirectML-ready Automatic1111 image; Ollama can stay CPU-only.|

Shared assets (Modelfiles, scripts, evidence) live in the repository and sync across hosts via Git. `.env` values are tuned per host after running `./scripts/bootstrap.ps1`.

## Overlay Responsibilities
- **`docker-compose.gpu.yml`** – switches the Ollama container to GPU mode on supported NVIDIA hosts.
- **`docker-compose.openwebui.yml`** – adds the Open WebUI frontend and forwards requests to the Ollama API on the Docker network.
- **`docker-compose.automatic1111.directml.yml`** – provisions an Automatic1111 container with DirectML flags and bind mounts for models/configs. Set `SD_WEBUI_IMAGE` in `.env` to a DirectML-compatible build before starting the overlay.

Each overlay stays optional. Combine them with the baseline manifest as needed:
```powershell
# Host 1 – GPU + Open WebUI
./scripts/compose.ps1 up -File docker-compose.gpu.yml -File docker-compose.openwebui.yml

# Host 2 – Automatic1111 (DirectML) only
./scripts/compose.ps1 up -File docker-compose.automatic1111.directml.yml
```

## Docker Context Strategy
Manage both hosts from a single shell by creating named contexts:
```powershell
# Configure once per remote host
docker context create host1 --docker "host=ssh://user@host1"
docker context create host2 --docker "host=ssh://user@host2"

# Target a specific host via compose helper
./scripts/compose.ps1 up -Context host1 -File docker-compose.gpu.yml
./scripts/compose.ps1 up -Context host2 -File docker-compose.automatic1111.directml.yml
```
`-Context` is optional; omit it to operate on the local Docker daemon.

## Current Architecture Sketch
```
                   SSH / Docker Context Switch
        ┌──────────────────────────────────────────┐
        │                                          │
┌───────┴────────┐                        ┌────────┴───────┐
│ Host 1: Win11   │                        │ Host 2: Win11  │
│ + WSL2 backend  │                        │ (native)       │
│ - compose.ps1   │                        │ - compose.ps1  │
│   + gpu.yml     │                        │   + automatic1111 overlay│
│   + openwebui   │                        │                │
│ - NVIDIA GPU    │                        │ - AMD + DirectML│
│ - Ollama + UI   │                        │ - Automatic1111 │
└────────┬────────┘                        └────────┬───────┘
         │      Shared repository (Git, Modelfiles, evidence)
         └───────────────────────────────────────────┘
```

## Next Steps
- Ship automated smoke tests for the new overlays once GPU/DirectML runners are available.
- Provide host-specific bootstrap presets (PowerShell profiles) to speed up `.env` tuning per workstation.
