# Summary
Broaden test coverage to validate runtime stack health, add coverage reporting, and enforce quality gates in CI.

# Scope
- Add integration tests that spin up compose, perform inference, and verify persistence in `data/` (extend `tests/` suites).
- Expand Pester coverage for PowerShell scripts beyond presence checks (see `tests/pester/scripts.Tests.ps1`).
- Emit coverage reports (`pytest --cov`, Pester code coverage) and surface them in `.github/workflows/smoke-tests.yml`.
- Update `TODO.md:6` and project docs with the new testing expectations.

# Acceptance Criteria
- [ ] New tests exercise compose lifecycle and sample requests end-to-end.
- [ ] CI fails when coverage drops below agreed thresholds.
- [ ] README/AGENTS describe how to run the expanded test suites locally.
