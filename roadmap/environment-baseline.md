# Summary
Refresh the published environment fingerprint so it matches the documented baseline (PowerShell 7+, Docker, Git, Python, Node).

# Scope
- Regenerate `docs/ENVIRONMENT.md` using `./scripts/bootstrap.ps1 -Report` on a compliant host (see README validation note around line 20).
- Capture the corresponding evidence artifact under `docs/evidence/environment/`.
- Update documentation (`README.md`, `AGENTS.md`) with the regeneration procedure and align `TODO.md:5`.

# Acceptance Criteria
- [ ] New `docs/ENVIRONMENT.md` reflects current host tooling and versions.
- [ ] Evidence bundle stored under `docs/evidence/environment/` and linked from docs.
- [ ] Instructions for regenerating the report included in README/AGENTS with prerequisites listed.
