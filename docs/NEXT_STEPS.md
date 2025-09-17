1. Run fresh validation: python -m pytest, Invoke-Pester -Path tests\pester, and docker compose -f infra\compose\docker-compose.yml config.
2. Benchmark via container: ./scripts/clean/bench_ollama.ps1 -Model llama31-8b-gpu -PromptPath docs\prompts\bench-default.txt -Iterations 3.
3. Capture telemetry: ./scripts/clean/capture_state.ps1 -OutputRoot docs\evidence\ci.
4. Execute context sweep using desired profile: ./scripts/context-sweep.ps1 -Safe -Profile qwen3-balanced -WriteReport.
5. Commit refreshed artifacts (docs/ENVIRONMENT.md, docs/evidence/) alongside updated tests and documentation.