# Codex Automation Guide (Private Hardware Stack)

## Scope
- Adapts the advanced Codex CLI non-interactive guidance to this repository's Docker Compose, PowerShell, and Windows-first workflows.
- Highlights the configuration points that must be adjusted so unattended Codex sessions can run audits, documentation updates, or release prep alongside the existing smoke tests.

## Integration Markers
- **Marker (.github/workflows/smoke-tests.yml)** add an optional Codex stage after the context sweep so automated audits run only when the stack is healthy. Reuse the bootstrap/environment steps that already prepare `.env`, `data/`, `models/`, and `docs/evidence/` so Codex inherits the same runtime surface.
- **Marker (.github/workflows/syntax-check.yml)** gate new prompts or Codex scripts with a dry-run job (for example `codex exec --full-auto "noop"`) before linting to catch authentication or CLI drift early.
- **Marker (scripts/bootstrap.ps1)** extend the existing `Ensure-EnvEntry` block when introducing Codex-specific variables (approval policy, sandbox mode, telemetry paths) so local and CI environments get identical defaults after `./scripts/bootstrap.ps1 -PromptSecrets`.
- **Marker (.env.example)** document every Codex-related variable that bootstrap seeds (`OLLAMA_API_KEY`, `CODEX_APPROVAL_POLICY`, `CODEX_SANDBOX_MODE`, `CODEX_LOG_ROOT`) with safe placeholders that keep CPU-only hosts working.
- **Marker (.gitignore)** ignore `docs/evidence/codex/` (mirroring `docs/evidence/precommit/`) once Codex logs are generated; do this before pipelines begin writing artifacts.
- **Marker (docs/ENVIRONMENT.md)** capture Codex CLI version, approval policy, and sandbox settings via `./scripts/bootstrap.ps1 -Report` so MPC/CI traces include audit context.
- **Marker (docs/evidence/)** create `docs/evidence/codex/` for session logs, pipeline transcripts, and MCP manifests so Codex output lives beside context sweeps, benchmarks, and state capture.

## Non-Interactive / CI Execution
- Install Codex inside GitHub Actions using the Node runtime already present for other tools:

```yaml
  - name: Install Codex CLI
    run: |
      npm install -g @openai/codex
      codex --version
```

- Reuse the existing `.env` preparation from `smoke-tests.yml`; the Codex job should depend on the compose bring-up so the agent can reach Ollama/Qdrant/Open WebUI endpoints when it evaluates health.
- Example audit stage (append near the end of `smoke-tests.yml` and guard it behind a secret):

```yaml
  - name: Run Codex repository audit
    if: ${{ secrets.CODEX_API_KEY != '' }}
    env:
      OPENAI_API_KEY: ${{ secrets.CODEX_API_KEY }}
      OLLAMA_API_KEY: ${{ secrets.OLLAMA_API_KEY }}
      RUST_LOG: codex_core=info,codex_exec=info
      CODEX_APPROVAL_POLICY: never
      CODEX_SANDBOX_MODE: workspace-write
    run: |
      npm install -g @openai/codex
      codex login --api-key "$OPENAI_API_KEY"
      mkdir -p docs/evidence/codex
      codex exec --full-auto "audit the repository for release readiness gaps" \
        | tee docs/evidence/codex/ci-run.log
```

- Use `--full-auto` to avoid approval prompts; keep approval policy `never` in CI so the job does not pause waiting for input.
- If the audit needs a warm stack, call `./scripts/compose.ps1 logs` or `python scripts/wait_for_http.py ...` first (the smoke job already does this).

## Resuming Sessions
- Persist session IDs for long-running audits by capturing Codex STDOUT into `docs/evidence/codex/session-last.log`; developers can resume with `codex resume --last` after syncing the repository.
- When CI produces a session identifier, upload it as an artifact (for example `actions/upload-artifact`) so operators can inspect the audit locally.
- Mirror the resume command inside `scripts/codex/run-audit.ps1` (new helper) so local runs match CI flags.

## Logging & Tracing
- Codex exec mode logs inline unless `RUST_LOG` is set. Export `RUST_LOG=codex_core=info,codex_exec=debug` to capture detailed traces in CI output; pipe the same stream into `docs/evidence/codex/*.log` via `tee` for archival.
- For TUI sessions, tail `~/.codex/log/codex-tui.log` (documented location) and copy relevant excerpts into `docs/evidence/codex/` when filing release evidence.
- If persistent log storage is required, introduce a bootstrap helper (for example `scripts/logging/watch-codex.ps1`) that follows the env-report pattern and writes into the evidence tree with timestamps.

## MCP Integration Path
- Configure Codex as an MCP client by adding entries to `~/.codex/config.toml`; document expected MCP servers under `docs/ARCHITECTURE.md` once validated.
- When exposing Codex as an MCP server, place launch scripts in `scripts/mcp/` and record invocation examples under `docs/prompts/` so other agents can reuse them.
- Add MCP health checks to the bootstrap dependency table (next to Docker, Codex, curl) so operators see missing tooling during `./scripts/bootstrap.ps1` runs.

## Security & Secrets Handling
- Keep API keys out of source control. Inject them through GitHub Secrets (`secrets.CODEX_API_KEY`) and rely on `./scripts/bootstrap.ps1 -PromptSecrets` to remind local operators to provide their own values.
- Default `.env.example` to dummy values (`CODEX_API_KEY=insert-local-token`, `CODEX_APPROVAL_POLICY=never`) so unattended environments fail closed when secrets are absent.
- Use scoped API tokens that can only access the required Codex projects; rotate them via your secrets manager and regenerate `.env` after changes.

## Local Developer Workflow
- Provide a thin wrapper script (e.g. `scripts/codex/run-audit.ps1`) that loads `.env`, checks for the CLI (`codex --version`), and executes the same `codex exec --full-auto` command the CI job uses.
- Encourage developers to run `./scripts/precommit.ps1 -Mode quick` before invoking Codex so structural checks pass before automation spends GPU/CPU resources.
- For sequential GPU experiments triggered by Codex, ensure `./scripts/model.ps1 create-all -MainGpu <index>` has been executed and the GPU compose overlay is active; Codex sessions can call these scripts directly once the sandbox is configured.
- Store Codex-generated reports in `docs/evidence/codex/` with timestamps (for example `codex-audit-20250918.md`) to keep parity with existing evidence artefacts.
