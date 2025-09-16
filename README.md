# Local AI Infrastructure (Cloud-Independent, OSS)

This repository scaffolds a local, open-source AI stack using Docker Compose. It runs fully on your machine with no cloud dependency.

## Prerequisites
- Windows 11 (WSL2 optional), admin rights
- Docker Desktop (with "Use the WSL 2 based engine" enabled)
- Git

Optional: Python 3.10+, Node.js LTS, PowerShell 7 for scripts.

## Quickstart
1) Copy `.env.example` to `.env` and adjust ports/paths.
2) Start the stack: `./scripts/compose.ps1 up` (PowerShell).
3) Open WebUI: http://localhost:3000 (connects to local Ollama at http://localhost:11434).

## Components
- Ollama: Local LLM runtime and model manager
- Open WebUI: Web interface for chat and orchestration
- Qdrant: Vector database for embeddings/RAG

See `docs/ARCHITECTURE.md` for details.

## Development
- Edit compose config in `infra/compose/docker-compose.yml`.
- Place persistent data under `data/` and models under `models/` (git-ignored).
- Update environment report via `./scripts/bootstrap.ps1 -Report` and read `docs/ENVIRONMENT.md`.

