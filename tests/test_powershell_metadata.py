"""Cross-platform smoke tests for PowerShell helper scripts.

These tests mirror the intent of the Pester suite so contributors without
PowerShell can still validate the repo state.
"""

from __future__ import annotations

from pathlib import Path
import re

REPO_ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (REPO_ROOT / relative_path).read_text(encoding="utf-8")


def test_get_env_value_extracts_value_group() -> None:
    scripts = [
        "scripts/bootstrap.ps1",
        "scripts/context-sweep.ps1",
        "scripts/clean/prune_evidence.ps1",
        "scripts/clean/capture_state.ps1",
        "scripts/clean/bench_ollama.ps1",
    ]
    for script in scripts:
        content = read_text(script)
        assert "return $Matches[2]" in content, f"{script} should capture the value portion of .env entries"


def test_compose_script_exposes_expected_actions() -> None:
    content = read_text("scripts/compose.ps1")
    assert re.search(r"ValidateSet\('up','down','restart','logs'\)", content)


def test_bootstrap_supports_prompt_secrets_switch() -> None:
    content = read_text("scripts/bootstrap.ps1")
    assert re.search(r"\[switch\]\$PromptSecrets", content)


def test_bootstrap_seeds_context_sweep_profile() -> None:
    content = read_text("scripts/bootstrap.ps1")
    pattern = re.compile(
        r"function\s+Invoke-WorkspaceProvisioning.*?Ensure-EnvEntry\s+-Path\s+\$envLocal\s+-Key\s+'CONTEXT_SWEEP_PROFILE'",
        re.DOTALL,
    )
    assert pattern.search(content)


def test_context_sweep_lists_builtin_profiles() -> None:
    content = read_text("scripts/context-sweep.ps1")
    for profile in ("llama31-long", "qwen3-balanced", "cpu-baseline"):
        assert profile in content


def test_eval_context_exposes_cpu_only_switch() -> None:
    content = read_text("scripts/eval-context.ps1")
    assert re.search(r"\[switch\]\$CpuOnly", content)


def test_eval_context_avoids_process_exit_on_error() -> None:
    content = read_text("scripts/eval-context.ps1")
    assert "exit 1" not in content.lower(), "eval-context.ps1 should not terminate the calling session on failure"
