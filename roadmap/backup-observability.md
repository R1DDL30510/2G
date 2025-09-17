# Summary
Automate backups for `data/open-webui` and `data/qdrant` and enhance observability guidance with GPU telemetry and log aggregation.

# Scope
- Create scripts (PowerShell/Bash) to snapshot and restore the critical volumes referenced in `infra/compose/docker-compose.yml:27-35`.
- Document recommended storage locations, retention, and restore drills in `docs/STACK_STATUS_2025-09-16.md` and README.
- Extend observability docs with GPU metrics collection and log aggregation patterns leveraging `scripts/clean/capture_state.ps1` outputs.
- Align with `TODO.md:7` so the backlog reflects completion.

# Acceptance Criteria
- [ ] Backup and restore commands tested and documented, including schedule guidance.
- [ ] Observability section covers GPU telemetry, log scraping, and alerting entry points.
- [ ] Evidence of a successful restore exercise captured in `docs/evidence/`.
