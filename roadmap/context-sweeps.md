# Summary
Automate GPU-capable context sweeps so evidence (Markdown/JSON) lands in `docs/evidence/` without manual triggers.

# Scope
- Wrap `./scripts/context-sweep.ps1 -Safe -WriteReport` in a scheduled task or GitHub Actions workflow (refs `.github/workflows/smoke-tests.yml:55`).
- Ensure artifacts are versioned or retained in `docs/evidence/` with rotation policies.
- Update `README.md` (validation section) and `TODO.md:4` to reflect the automation.

# Acceptance Criteria
- [ ] Automated job runs sweeps with GPU profile when available, CPU fallback otherwise.
- [ ] Evidence files are timestamped and stored under `docs/evidence/` with retention guidance.
- [ ] Documentation explains how/when the automation runs and how to review outputs.
