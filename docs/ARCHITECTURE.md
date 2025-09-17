# Architecture Overview

Components (all local, open-source):
- Ollama (`ollama/ollama:0.11.11`): pulls and runs LLMs locally.
- Open WebUI (`ghcr.io/open-webui/open-webui:v0.3.7`): chat UI connected to Ollama.
- Qdrant (`qdrant/qdrant:v1.15.4`): vector database for embeddings/RAG.

Data & Models
- `models/`: cache for Ollama models (large, not tracked).
- `data/`: persistent volumes for services (e.g., Qdrant).

Networking
- Web UI: http://localhost:3000
- Ollama: http://localhost:11434
- Qdrant API: http://localhost:6333

Images pinned in `infra/compose/docker-compose.yml` keep the stack stable; update after validating upstream releases.

Customize by editing `infra/compose/docker-compose.yml` and `.env`.
