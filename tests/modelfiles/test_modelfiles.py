"""Smoke tests covering the repository's Modelfiles."""
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = ROOT / "modelfiles"


def iter_modelfiles() -> list[Path]:
    files = sorted(MODELS_DIR.glob("*.Modelfile"))
    assert files, "No Modelfiles were discovered under modelfiles/"
    return files


def normalise_lines(path: Path) -> list[str]:
    meaningful: list[str] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        meaningful.append(stripped)
    return meaningful


def test_single_modelfile_declared() -> None:
    files = iter_modelfiles()
    assert len(files) == 1, f"Expected a single Modelfile, found {len(files)}"


def test_modelfile_uses_llama3_base() -> None:
    file_path = iter_modelfiles()[0]
    lines = normalise_lines(file_path)
    assert lines[0] == "FROM llama3.1", f"{file_path.name} should inherit from llama3.1"


def test_modelfile_exposes_passthrough_template() -> None:
    lines = normalise_lines(iter_modelfiles()[0])
    assert any(line.startswith("TEMPLATE \"\"\"{{ .Prompt }}\"\"\"") for line in lines), "Modelfile should forward prompts verbatim"


def test_context_window_parameters_are_positive() -> None:
    lines = normalise_lines(iter_modelfiles()[0])
    ctx_lines = [line for line in lines if line.startswith("PARAMETER num_ctx")]
    assert ctx_lines, "Modelfile should declare a context window"
    for line in ctx_lines:
        parts = line.split()
        value = parts[-1]
        assert value.isdigit() and int(value) > 0, f"Invalid context window declared: {line}"
