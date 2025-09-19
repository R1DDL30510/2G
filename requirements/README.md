# Dependency Index

All dependency surfaces terminate in this folder so documentation, local workflows, and CI reference the same source of truth.

## Python
- `requirements/python/base.txt` – minimal pytest toolchain shared by every environment.
- `requirements/python/dev.txt` – roll-up for day-to-day work. Install it with `python -m pip install -r requirements/python/dev.txt`.
- `requirements/python/ci.txt` – thin wrapper consumed by GitHub Actions. It simply reuses `base.txt` so automation cannot drift from local installs.

## PowerShell
- Pester installs happen on demand in CI via `Install-Module Pester -Scope CurrentUser`.
- Run `pwsh -Command "Install-Module Pester -Scope CurrentUser"` once locally to mirror the same tooling.

## Node.js
- Optional CLI helpers read from `package.json`. Run `npm install` only when you need those scripts; the stack itself does not require Node.js.

## Environment templates
- `.env.example` is the canonical runtime template. The bootstrap script copies it to `.env` and fills in paths so the compose helpers and workflows use the same configuration keys.

Keeping every reference here preserves the modular design: nothing is pinned, but when you upgrade an image or tool remember to update the appropriate requirement file and record the change in `docs/STATE_VERIFICATION.md`.
