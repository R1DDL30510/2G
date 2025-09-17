# Catch-Up Priorities

- [ ] Run and archive a GPU context sweep using `./scripts/context-sweep.ps1 -Safe -WriteReport` so CUDA paths are validated and the markdown report lands under `docs/`.
- [ ] Extend smoke automation with runtime health probes and coverage tooling, ensuring CI emits evidence under `docs/evidence/` for each run.
- [ ] Stabilise operator tooling by rerunning `./scripts/bootstrap.ps1 -PromptSecrets`, confirming PowerShell 7+, Docker, Git, and other dependencies exist, then recreating context models.
- [ ] Document and automate backup and recovery for `data/open-webui` and `data/qdrant`, capturing the procedure and test restores in `docs/`.
- [ ] Enrich architecture and monitoring documentation (e.g., `docs/ARCHITECTURE.md`) with diagrams and telemetry conventions to guide onboarding and observability work.
