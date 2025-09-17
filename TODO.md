# Catch-Up Priorities (Aligned to Sept 2025 State Report)

- [ ] Reconcile the model inventory by updating `./scripts/model.ps1 create-all` (or documenting the manual step) so the `llama31-8b-gpu` profile described in reports can be recreated automatically.
- [ ] Automate GPU-enabled context sweeps via `./scripts/context-sweep.ps1 -Safe -WriteReport` and publish the resulting Markdown/JSON artifacts under `docs/evidence/` to close the current evidence gap.
- [ ] Regenerate `docs/ENVIRONMENT.md` from a host with PowerShell 7+, Docker, Git, Python, and Node installed so dependency checks match the documented baseline.
- [ ] Expand the pytest and forthcoming Pester suites to cover runtime stack health, compose lifecycle, and script behaviours; gate pull requests in CI with these checks and persist coverage reports.
- [ ] Formalise backup and restore automation for `data/open-webui` and `data/qdrant`, and extend observability documentation with GPU telemetry and log aggregation guidance.
