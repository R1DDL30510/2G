# Dependency Index

This folder centralises tooling requirements across the stack so CI and local workflows stay aligned.

## Python
- `requirements/python/base.txt` – shared pytest tooling used everywhere.
- `requirements/python/dev.txt` – roll-up used for local development (`pip install -r requirements/python/dev.txt`).
- `requirements/python/ci.txt` – lean set consumed by GitHub Actions.

## PowerShell
- Pester modules are installed on demand in CI via `Install-Module Pester -Scope CurrentUser`.
- Local runs should install Pester once using `pwsh -Command "Install-Module Pester -Scope CurrentUser"`.

## Node.js
- Runtime integration scripts rely on the packages declared in `package.json`; run `npm install` to restore them when needed.

Keeping the lists in one place prevents the workflows, docs, and developer tooling from drifting.
