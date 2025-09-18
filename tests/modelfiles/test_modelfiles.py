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


def test_modelfiles_share_base_model() -> None:
    for file_path in iter_modelfiles():
        lines = normalise_lines(file_path)
        assert lines[0] == "FROM llama3.1:8b", f"{file_path.name} should inherit from llama3.1:8b"


def test_gpu_modelfile_declares_gpu_parameters() -> None:
    gpu_file = MODELS_DIR / "llama31-8b-gpu.Modelfile"
    assert gpu_file.exists(), "GPU-optimised Modelfile must exist"

    lines = normalise_lines(gpu_file)
    assert any(line.startswith("PARAMETER num_gpu") for line in lines), "GPU Modelfile must request GPU layers"
    main_gpu_lines = [line for line in lines if line.startswith("PARAMETER main_gpu")]
    assert main_gpu_lines == [
        "PARAMETER main_gpu 1"
    ], "GPU Modelfile must nominate GPU index 1 by default"


def test_context_window_parameters_are_positive() -> None:
    for file_path in iter_modelfiles():
        lines = normalise_lines(file_path)
        ctx_lines = [line for line in lines if line.startswith("PARAMETER num_ctx")]
        for line in ctx_lines:
            parts = line.split()
            value = parts[-1]
            assert value.isdigit() and int(value) > 0, f"{file_path.name} contains invalid context window: {line}"
