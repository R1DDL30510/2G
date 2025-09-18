"""Smoke tests for docker-compose configuration integrity without requiring PyYAML."""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List


ROOT = Path(__file__).resolve().parents[2]
COMPOSE_PATH = ROOT / "infra" / "compose" / "docker-compose.yml"
GPU_COMPOSE_PATH = ROOT / "infra" / "compose" / "docker-compose.gpu.yml"


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


def test_compose_declares_expected_services() -> None:
    expected_services = {"ollama", "ollama-gpu0", "ollama-gpu1", "open-webui", "qdrant"}
    missing = expected_services.difference(SERVICES_CACHE)
    assert not missing, f"missing required services: {sorted(missing)}"


def test_isolated_gpu_services_default_to_cpu() -> None:
    for name, port_key, cpu_key in (
        ("ollama-gpu0", "OLLAMA_GPU0_PORT", "OLLAMA_GPU0_USE_CPU"),
        ("ollama-gpu1", "OLLAMA_GPU1_PORT", "OLLAMA_GPU1_USE_CPU"),
    ):
        service = SERVICES_CACHE[name]

        environment: List[str] = service.get("environment", [])  # type: ignore[assignment]
        assert "OLLAMA_HOST=0.0.0.0" in environment, f"{name} must bind to 0.0.0.0"
        expected_cpu = "OLLAMA_USE_CPU=${" + cpu_key + ":-true}"
        assert expected_cpu in environment, f"{name} must default to CPU mode"

        ports: List[str] = service.get("ports", [])  # type: ignore[assignment]
        default_port = "11435" if name.endswith("0") else "11436"
        expected_port = "${" + port_key + ":-" + default_port + "}:11434"
        assert any(entry.strip('"') == expected_port for entry in ports), f"{name} must expose a host port"

        volumes: List[str] = service.get("volumes", [])  # type: ignore[assignment]
        assert any("../../modelfiles" in volume for volume in volumes), f"{name} must mount modelfiles"


def test_images_are_pinned_and_not_latest() -> None:
    for name, definition in SERVICES_CACHE.items():
        image = definition.get("image")
        assert isinstance(image, str) and image, f"{name} must declare an image"
        assert ":" in image, f"{name} image must include a tag"
        tag = image.split(":", maxsplit=1)[1]
        assert tag and tag.lower() != "latest", f"{name} image must pin a non-latest tag"



def test_open_webui_depends_on_ollama() -> None:
    open_webui = SERVICES_CACHE["open-webui"]
    depends = open_webui.get("depends_on", [])
    assert "ollama" in depends, "open-webui service must depend on ollama"



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




def test_gpu_overlay_pins_isolated_devices() -> None:
    for name, visible_key, cpu_key, allocation_key, default_device in (
        ("ollama-gpu0", "OLLAMA_GPU0_VISIBLE_GPUS", "OLLAMA_GPU0_USE_CPU", "OLLAMA_GPU0_GPU_ALLOCATION", "0"),
        ("ollama-gpu1", "OLLAMA_GPU1_VISIBLE_GPUS", "OLLAMA_GPU1_USE_CPU", "OLLAMA_GPU1_GPU_ALLOCATION", "1"),
    ):
        service = GPU_SERVICES_CACHE[name]

        environment: List[str] = service.get("environment", [])  # type: ignore[assignment]
        expected_pairs = {
            "NVIDIA_VISIBLE_DEVICES=${" + visible_key + ":-" + default_device + "}",
            "NVIDIA_DRIVER_CAPABILITIES=compute,utility",
            "OLLAMA_USE_CPU=${" + cpu_key + ":-false}",
        }
        for pair in expected_pairs:
            assert pair in environment, f"{name} GPU overlay environment missing {pair}"

        expected_gpus = "${" + allocation_key + ":-device=" + default_device + "}"
        assert service.get("gpus") == expected_gpus, f"{name} GPU allocation should request a single device"


def test_open_webui_uses_expected_env_defaults() -> None:
    open_webui = SERVICES_CACHE["open-webui"]

    environment: List[str] = open_webui.get("environment", [])  # type: ignore[assignment]
    expected_pairs = {
        "OLLAMA_BASE_URL=http://ollama:11434",
        "WEBUI_AUTH=${OPENWEBUI_AUTH:-false}",
    }
    for pair in expected_pairs:
        assert pair in environment, f"open-webui environment missing {pair}"



def test_qdrant_persists_data_volume() -> None:
    qdrant = SERVICES_CACHE["qdrant"]

    volumes: List[str] = qdrant.get("volumes", [])  # type: ignore[assignment]
    assert any("/qdrant/storage" in volume for volume in volumes), "qdrant must persist storage volume"
