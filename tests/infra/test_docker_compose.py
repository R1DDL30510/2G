"""Smoke tests for docker-compose configuration integrity without requiring PyYAML."""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List


ROOT = Path(__file__).resolve().parents[2]
COMPOSE_PATH = ROOT / "infra" / "compose" / "docker-compose.yml"
GPU_COMPOSE_PATH = ROOT / "infra" / "compose" / "docker-compose.gpu.yml"
OPENWEBUI_COMPOSE_PATH = ROOT / "infra" / "compose" / "docker-compose.openwebui.yml"
DIRECTML_COMPOSE_PATH = ROOT / "infra" / "compose" / "docker-compose.automatic1111.directml.yml"


def parse_services(path: Path = COMPOSE_PATH) -> Dict[str, Dict[str, object]]:
    """Parse the compose file using indentation-aware heuristics."""
    lines = path.read_text(encoding="utf-8").splitlines()
    services: Dict[str, Dict[str, object]] = {}
    in_services = False
    current_service: str | None = None
    current_list_key: str | None = None

    for raw in lines:
        stripped_line = raw.strip()
        if not stripped_line or stripped_line.startswith("#"):
            continue

        if stripped_line == "services:":
            in_services = True
            current_service = None
            current_list_key = None
            continue

        if not in_services:
            continue

        indent = len(raw) - len(raw.lstrip(" "))

        if indent == 2 and stripped_line.endswith(":"):
            current_service = stripped_line[:-1]
            services[current_service] = {}
            current_list_key = None
            continue

        if indent <= 2:
            in_services = False
            current_service = None
            current_list_key = None
            continue

        if current_service is None:
            continue

        if indent == 4 and ":" in stripped_line:
            key, value = stripped_line.split(":", 1)
            key = key.strip()
            value = value.strip()
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]

            if value:
                services[current_service][key] = value
                current_list_key = None
            else:
                services[current_service][key] = []
                current_list_key = key
            continue

        if indent >= 6 and stripped_line.startswith("-") and current_list_key:
            entry = stripped_line[1:].strip()
            services[current_service].setdefault(current_list_key, []).append(entry)

    return services


SERVICES_CACHE = parse_services()
GPU_SERVICES_CACHE = parse_services(GPU_COMPOSE_PATH)
OPENWEBUI_SERVICES_CACHE = parse_services(OPENWEBUI_COMPOSE_PATH)
DIRECTML_SERVICES_CACHE = parse_services(DIRECTML_COMPOSE_PATH)


def test_compose_declares_only_ollama_service() -> None:
    assert set(SERVICES_CACHE) == {"ollama"}, f"unexpected services defined: {sorted(SERVICES_CACHE)}"


def test_ollama_image_uses_env_override() -> None:
    ollama = SERVICES_CACHE["ollama"]
    image = ollama.get("image")
    assert isinstance(image, str) and image, "ollama must declare an image override"
    assert image == "${OLLAMA_IMAGE:-ollama/ollama}", "ollama image should defer to environment override"


def test_ollama_defaults_to_cpu_mode() -> None:
    ollama = SERVICES_CACHE["ollama"]

    assert ollama.get("gpus") is None, "ollama should not request GPUs by default"

    environment: List[str] = ollama.get("environment", [])  # type: ignore[assignment]
    assert any(entry == "OLLAMA_HOST=0.0.0.0" for entry in environment), "OLLAMA_HOST must be bound to 0.0.0.0"
    assert (
        "OLLAMA_USE_CPU=${OLLAMA_USE_CPU:-true}" in environment
    ), "OLLAMA must default to CPU mode"
    assert not any(
        entry.startswith("NVIDIA_VISIBLE_DEVICES") for entry in environment
    ), "CPU default must not request NVIDIA devices"

    volumes: List[str] = ollama.get("volumes", [])  # type: ignore[assignment]
    assert any("../../modelfiles" in volume for volume in volumes), "ollama volume mounts must include modelfiles"
    assert any(
        volume.strip('"') == "../../${MODELS_DIR:-models}:/root/.ollama" for volume in volumes
    ), "ollama should persist models using MODELS_DIR override"


def test_gpu_overlay_requests_cuda_resources() -> None:
    ollama = GPU_SERVICES_CACHE["ollama"]

    assert (
        ollama.get("gpus") == "${OLLAMA_GPU_ALLOCATION:-all}"
    ), "GPU overlay must request GPU resources (all) by default"

    environment: List[str] = ollama.get("environment", [])  # type: ignore[assignment]
    expected_pairs = {
        "NVIDIA_VISIBLE_DEVICES=${OLLAMA_VISIBLE_GPUS:-all}",
        "NVIDIA_DRIVER_CAPABILITIES=compute,utility",
        "OLLAMA_USE_CPU=${OLLAMA_USE_CPU:-false}",
    }
    for pair in expected_pairs:
        assert pair in environment, f"GPU overlay environment missing {pair}"


def test_openwebui_overlay_links_to_ollama() -> None:
    openwebui = OPENWEBUI_SERVICES_CACHE["openwebui"]

    assert (
        openwebui.get("image")
        == "${OPENWEBUI_IMAGE:-ghcr.io/open-webui/open-webui:main}"
    ), "Open WebUI overlay should expose image override"

    environment: List[str] = openwebui.get("environment", [])  # type: ignore[assignment]
    assert (
        "OLLAMA_BASE_URL=${OPENWEBUI_OLLAMA_URL:-http://ollama:11434}" in environment
    ), "Open WebUI overlay should reference Ollama base URL"
    assert (
        "WEBUI_SECRET_KEY=${OPENWEBUI_SECRET_KEY:-changeme}" in environment
    ), "Open WebUI overlay must allow secret override"

    ports: List[str] = openwebui.get("ports", [])  # type: ignore[assignment]
    assert any(
        entry.strip('"') == "${OPENWEBUI_PORT:-3000}:8080" for entry in ports
    ), "Open WebUI overlay should publish configurable host port"

    depends_on: List[str] = openwebui.get("depends_on", [])  # type: ignore[assignment]
    assert depends_on == ["ollama"], "Open WebUI overlay must depend on ollama"


def test_directml_overlay_requires_image_override() -> None:
    directml = DIRECTML_SERVICES_CACHE["stable-diffusion"]

    assert directml.get("image") == "${SD_WEBUI_IMAGE:?Set SD_WEBUI_IMAGE in .env to a DirectML-compatible Automatic1111 build}", (
        "DirectML overlay must require SD_WEBUI_IMAGE override"
    )

    environment: List[str] = directml.get("environment", [])  # type: ignore[assignment]
    assert (
        "COMMANDLINE_ARGS=${SD_WEBUI_COMMANDLINE_ARGS:---use-directml --medvram}" in environment
    ), "DirectML overlay should expose CLI arguments override"

    ports: List[str] = directml.get("ports", [])  # type: ignore[assignment]
    assert any(
        entry.strip('"') == "${SD_WEBUI_PORT:-7860}:7860" for entry in ports
    ), "DirectML overlay must publish default Stable Diffusion port"

    volumes: List[str] = directml.get("volumes", [])  # type: ignore[assignment]
    expected_volumes = {
        "../../${SD_WEBUI_MODELS_DIR:-models/stable-diffusion}:/data/models",
        "../../${SD_WEBUI_CONFIG_DIR:-configs/stable-diffusion}:/data/config",
    }
    assert expected_volumes.issubset(set(volumes)), "DirectML overlay must mount model and config directories"

