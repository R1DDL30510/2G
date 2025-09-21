# Minimal Stack Follow-Ups

- [ ] Document a sample overlay in `docs/STATE_VERIFICATION.md` that demonstrates how to add a secondary service without bloating the baseline compose file.
- [ ] Extend the pytest suite with a smoke test that exercises `docker-compose.gpu.yml` once GPU runners are available.
- [ ] Automate evidence pruning so `docs/evidence/` retains only the latest verification artefacts.
- [ ] Capture a reference host report after running the trimmed context sweep to provide reviewers with a fresh baseline.
- [ ] Create a helper script or bootstrap step that seeds Docker contexts for host1/host2 so multi-host orchestration is one command away.
