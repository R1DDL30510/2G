# Architecture Overview

Components (all local, open-source):
- Ollama (`ollama/ollama`): pulls and runs LLMs locally.
- Open WebUI (`ghcr.io/open-webui/open-webui`): chat UI connected to Ollama.
- Qdrant (`qdrant/qdrant`): vector database for embeddings/RAG.

Data & Models
- `models/`: cache for Ollama models (large, not tracked).
- `data/`: persistent volumes for services (e.g., Qdrant).

Networking
- Web UI: http://localhost:3000
- Ollama: http://localhost:11434
- Qdrant API: http://localhost:6333

Customize by editing `infra/compose/docker-compose.yml` and `.env`.

