"""Smoke tests ensuring the sample environment file stays aligned with the stack."""
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ENV_EXAMPLE = ROOT / ".env.example"
PROMPT_PATH = ROOT / "docs" / "prompts" / "bench-default.txt"


def load_env() -> dict[str, str]:
    env: dict[str, str] = {}
    for raw_line in ENV_EXAMPLE.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            raise AssertionError(f"Malformed line in .env.example: {raw_line}")
        key, value = stripped.split("=", maxsplit=1)
        env[key] = value
    return env


def test_context_profile_default_present() -> None:
    env = load_env()
    assert env["CONTEXT_SWEEP_PROFILE"] == "llama31-long", "context sweep default should be populated"

def test_env_example_contains_expected_keys() -> None:
    env = load_env()
    expected_keys = {
        "WEBUI_PORT",
        "OLLAMA_PORT",
        "QDRANT_PORT",
        "MODELS_DIR",
        "DATA_DIR",
        "OPENWEBUI_AUTH",
        "OLLAMA_API_KEY",
        "OLLAMA_BASE_URL",
        "OLLAMA_BENCH_MODEL",
        "OLLAMA_BENCH_PROMPT",
        "EVIDENCE_ROOT",
        "LOG_FILE",
    }
    missing = expected_keys.difference(env)
    assert not missing, f".env.example is missing keys: {sorted(missing)}"


def test_ports_are_numeric() -> None:
    env = load_env()
    for key in ("WEBUI_PORT", "OLLAMA_PORT", "QDRANT_PORT"):
        value = env[key]
        assert value.isdigit(), f"{key} should be a numeric port"


def test_prompt_reference_exists() -> None:
    env = load_env()
    prompt_value = env["OLLAMA_BENCH_PROMPT"]
    prompt_path = (ROOT / prompt_value).resolve()
    expected = PROMPT_PATH.resolve()
    assert prompt_path == expected, "OLLAMA_BENCH_PROMPT must point to docs/prompts/bench-default.txt"
    assert PROMPT_PATH.exists(), "benchmark prompt file should exist"


def test_relative_directories_are_not_absolute() -> None:
    env = load_env()
    for key in ("MODELS_DIR", "DATA_DIR", "EVIDENCE_ROOT", "LOG_FILE"):
        value = env[key]
        assert value.startswith("."), f"{key} should use a repository-relative path"
