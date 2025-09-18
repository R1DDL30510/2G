#!/usr/bin/env python3
"""Run a chain-of-experts style workflow across multiple Ollama endpoints sequentially.

This helper keeps only a single model loaded at a time.  Provide the initial
prompt via ``--prompt`` or ``--prompt-file`` and list the desired models with
``--step``.  Each step accepts ``model`` or ``model@endpoint``; append ``#`` and
instructions to specialise a stage, for example::

    python scripts/ollama_chain.py \
        --prompt "Entwirf eine REST-API für Kundenverwaltung." \
        --step "deepseek-coder:6.7b@http://localhost:11435#Implementiere den API-Entwurf" \
        --step "qwen2.5-coder:7b@http://localhost:11436#Prüfe den Code auf Bugs" \
        --step "llama3.1:8b#Erstelle die Dokumentation"

When no endpoint is provided the script falls back to ``$OLLAMA_BASE_URL`` or
``http://localhost:11434``.  Results are printed to stdout and can optionally be
written to a Markdown transcript with ``--transcript``.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Sequence, Tuple
from urllib import error, request

DEFAULT_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434")
DEFAULT_DIRECTIVE = "Review the previous response and continue the task."  # Applied to steps >= 2 unless overridden.


@dataclass
class Step:
    """Single stage within the sequential pipeline."""

    model: str
    endpoint: str
    directive: str | None = None

    def normalised_endpoint(self) -> str:
        endpoint = self.endpoint.strip()
        if not endpoint:
            endpoint = DEFAULT_BASE_URL
        if "//" not in endpoint:
            endpoint = f"http://{endpoint}"
        return endpoint.rstrip("/")

    @property
    def display_name(self) -> str:
        return self.model


def parse_step(raw: str, default_endpoint: str) -> Step:
    """Parse ``model[@endpoint][#directive]`` tokens into a :class:`Step`."""

    directive: str | None = None
    core = raw.strip()
    if not core:
        raise ValueError("Step definition may not be empty")

    if "#" in core:
        core, directive = core.split("#", maxsplit=1)
        directive = directive.strip() or None

    if "@" in core:
        model, endpoint = core.split("@", maxsplit=1)
        endpoint = endpoint.strip() or default_endpoint
    else:
        model, endpoint = core, default_endpoint

    model = model.strip()
    if not model:
        raise ValueError(f"Invalid step definition '{raw}': missing model name")

    return Step(model=model, endpoint=endpoint, directive=directive)


def load_prompt(prompt: str | None, prompt_file: str | None) -> str:
    if prompt and prompt_file:
        raise ValueError("Use either --prompt or --prompt-file, not both.")
    if prompt_file:
        content = Path(prompt_file).read_text(encoding="utf-8").strip()
        if not content:
            raise ValueError("Prompt file is empty.")
        return content
    if prompt:
        stripped = prompt.strip()
        if not stripped:
            raise ValueError("Prompt text cannot be empty.")
        return stripped
    raise ValueError("A starting prompt is required (use --prompt or --prompt-file).")


def format_history(entries: Sequence[Tuple[str, str]]) -> str:
    sections: List[str] = []
    for label, text in entries:
        clean = text.strip()
        if not clean:
            continue
        sections.append(f"### {label}\n{clean}")
    return "\n\n".join(sections)


def call_ollama(endpoint: str, model: str, prompt: str, timeout: float) -> str:
    payload = json.dumps({"model": model, "prompt": prompt, "stream": False}).encode("utf-8")
    url = f"{endpoint}/api/generate"
    req = request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        with request.urlopen(req, timeout=timeout) as response:
            body = response.read().decode("utf-8")
    except error.HTTPError as exc:  # pragma: no cover - network errors are surfaced to the caller.
        detail = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"{model} on {endpoint} returned HTTP {exc.code}: {detail}") from exc
    except error.URLError as exc:  # pragma: no cover - network errors are surfaced to the caller.
        raise RuntimeError(f"Failed to reach {endpoint}: {exc.reason}") from exc

    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:  # pragma: no cover - unexpected Ollama response.
        raise RuntimeError(f"Could not decode Ollama response: {body}") from exc

    result = payload.get("response")
    if not isinstance(result, str):
        raise RuntimeError(f"Ollama response is missing text output: {payload}")
    return result.strip()


def write_transcript(entries: Sequence[Tuple[str, str]], output_path: Path) -> None:
    lines = ["# Ollama Chain Transcript"]
    for label, text in entries:
        lines.append("")
        lines.append(f"## {label}")
        lines.append("")
        lines.append(text.strip() or "(leer)")
    output_path.write_text("\n".join(lines), encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run multiple Ollama models sequentially using a shared prompt history.")
    parser.add_argument("--prompt", help="Initial prompt passed to the first model.")
    parser.add_argument("--prompt-file", help="Read the initial prompt from a file.")
    parser.add_argument(
        "--step",
        dest="steps",
        action="append",
        required=True,
        help=(
            "Add a pipeline stage defined as model[@endpoint][#directive]. "
            "Repeat --step for each expert in the chain."
        ),
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="Fallback endpoint for steps without an explicit host (default: %(default)s).",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=120.0,
        help="HTTP timeout in seconds for each Ollama request (default: %(default)s).",
    )
    parser.add_argument(
        "--default-directive",
        default=DEFAULT_DIRECTIVE,
        help=(
            "Directive appended to steps without an explicit instruction. Set to an empty string to disable "
            "the automatic review hand-off (default: %(default)s)."
        ),
    )
    parser.add_argument(
        "--transcript",
        help="Optional path to write the full conversation transcript as Markdown.",
    )
    return parser


def run_pipeline(args: argparse.Namespace) -> None:
    prompt = load_prompt(args.prompt, args.prompt_file)
    steps = [parse_step(raw, args.base_url) for raw in args.steps]
    history: List[Tuple[str, str]] = [("User Prompt", prompt)]

    for index, step in enumerate(steps, start=1):
        directive = step.directive
        if directive is None and (index > 1 or args.default_directive.strip()):
            directive = args.default_directive.strip() or None
            if index == 1 and step.directive is None:
                # Do not force a default directive on the very first stage unless explicitly provided.
                directive = step.directive

        stage_prompt = format_history(history)
        if directive:
            stage_prompt = f"{stage_prompt}\n\n### Task for {step.display_name}\n{directive.strip()}"

        endpoint = step.normalised_endpoint()
        print(f"\n[Step {index}] Running {step.display_name} via {endpoint}...")
        response = call_ollama(endpoint, step.model, stage_prompt, timeout=args.timeout)
        print("--- Response ---")
        print(response)
        history.append((step.display_name, response))

    if args.transcript:
        output_path = Path(args.transcript)
        write_transcript(history, output_path)
        print(f"\nTranscript saved to {output_path.resolve()}")


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
        run_pipeline(args)
        return 0
    except Exception as exc:  # pragma: no cover - CLI surface for runtime errors.
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
