# Context Sweep Profiles

The sweep utility now supports multiple labeled profiles so you can continue testing long-context behaviour without hammering both GPUs at once.

## Built-in profiles

- `llama31-long`: reuses the existing Modelfiles but caps `num_gpu` at 1 and trims token targets/timeouts to keep 32k runs under 8–9k tokens in safe mode.
- `qwen3-balanced`: exercises `qwen3:8b` at 4k, 8k, and 12k contexts with conservative GPU allocation; ideal when you need quicker convergence or want to avoid llama3.1 thermal spikes.
- `cpu-baseline`: falls back to the published `llama3.1:8b` image and is intended for CI or workstations without CUDA—pair with `-CpuOnly` for deterministic comparisons.

## Choosing a profile

1. Set `CONTEXT_SWEEP_PROFILE` in `.env` (e.g. `qwen3-balanced` for thermal-sensitive hosts).
2. Run `./scripts/context-sweep.ps1 -Safe -WriteReport` to capture a markdown artifact tagged with the active profile.
3. For GPU validation, drop `-CpuOnly` and allow the helper to pass `num_gpu=1` plus the configured `main_gpu` to avoid cross-device contention.

## GPU scheduling & cooldown

- The sweep helper now inspects `nvidia-smi` at startup, prefers the GPU index defined by `DEFAULT_GPU_INDEX` (default `1` for the RTX 3060), and only fans out across all detected adapters when the preferred device is unavailable. Results and Markdown exports record which device serviced each run (`Device` column).
- When no CUDA devices are exposed the script logs a warning and automatically falls back to CPU mode—no extra flags required. You can still force CPU-only behaviour with `-CpuOnly` for deterministic baselines.
- To limit thermal spikes, each GPU hand-off sleeps for `GpuCooldownSec` seconds (default `15`) before the next invocation. Combine this with `-InterRunDelaySec` for additional headroom between prompts, or shorten the cooldown when you are sweeping cooler-running 3B/4B models.

## Additional model ideas

- **llama3.2:3b-instruct**: Works well when VRAM is limited (single 12 GB card) and happily runs with 8k contexts; add a custom profile by editing `scripts/context-sweep.ps1` or passing `-Profile` + plan overrides.
- **phi3.5:mini**: CPU-friendly 4B model that keeps latency predictable for nightly sweeps.
- **mistral-nemo:latest**: Higher quality long-context option (12B) that benefits from reduced token targets similar to the `llama31-long` defaults.

Document any custom profiles under `docs/evidence/` alongside benchmark outputs so future releases know which combinations were validated.

