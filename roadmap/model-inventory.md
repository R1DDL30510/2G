# Summary
Automate `scripts/model.ps1 create-all` so every Modelfile, including the GPU variant, can be rebuilt reproducibly without manual commands.

# Scope
- Extend `scripts/model.ps1` to iterate over all files in `modelfiles/`, including `modelfiles/llama31-8b-gpu.Modelfile`.
- Document the workflow in `README.md` (GPU guidance around line 62) and align `TODO.md:3`.
- Add regression coverage to ensure the helper invokes the expected Ollama CLI commands.

# Acceptance Criteria
- [ ] `./scripts/model.ps1 create-all` rebuilds every Modelfile and supports GPU flags.
- [ ] README and `AGENTS.md` describe the automation clearly.
- [ ] New or updated tests cover the helper logic (mocked Ollama calls).
