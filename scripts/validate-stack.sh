#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
ENV_TEMPLATE="$ROOT_DIR/.env.example"

if [[ ! -f "$ENV_TEMPLATE" ]]; then
  echo "Template environment file missing: $ENV_TEMPLATE" >&2
  exit 1
fi

ENV_CREATED=0
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_TEMPLATE" "$ENV_FILE"
  ENV_CREATED=1
  echo "Seeded $ENV_FILE from template"
fi

# shellcheck source=/dev/null
set -a
source "$ENV_FILE"
set +a

resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    # Strip leading ./ to avoid duplicate separators when joining.
    local trimmed="${path#./}"
    printf '%s/%s\n' "$ROOT_DIR" "$trimmed"
  fi
}

MODELS_PATH="$(resolve_path "${MODELS_DIR:-./models}")"
EVIDENCE_PATH="$(resolve_path "${EVIDENCE_ROOT:-./docs/evidence}")"
LOG_PATH="$(resolve_path "${LOG_FILE:-./logs/stack.log}")"

mkdir -p "$MODELS_PATH" "$EVIDENCE_PATH" "$(dirname "$LOG_PATH")"

COMPOSE_FILES=("$ROOT_DIR/infra/compose/docker-compose.yml")

if [[ "${STACK_VALIDATION_USE_GPU:-0}" == "1" ]]; then
  COMPOSE_FILES+=("$ROOT_DIR/infra/compose/docker-compose.gpu.yml")
fi

if [[ -n "${STACK_VALIDATION_EXTRA_FILES:-}" ]]; then
  read -r -a EXTRA_FILES <<<"${STACK_VALIDATION_EXTRA_FILES}"
  for extra in "${EXTRA_FILES[@]}"; do
    if [[ -f "$ROOT_DIR/$extra" ]]; then
      COMPOSE_FILES+=("$ROOT_DIR/$extra")
    else
      echo "Warning: requested compose overlay not found: $extra" >&2
    fi
  done
fi

compose_args=("--project-directory" "$ROOT_DIR" "--env-file" "$ENV_FILE")
for file in "${COMPOSE_FILES[@]}"; do
  compose_args+=(-f "$file")
  echo "Using compose file: $file"
  if [[ ! -f "$file" ]]; then
    echo "Compose file not found: $file" >&2
    exit 1
  fi
fi

compose_cmd() {
  docker compose "${compose_args[@]}" "$@"
}

cleanup() {
  local exit_code=$1
  if [[ $exit_code -ne 0 ]]; then
    compose_cmd logs || true
  fi
  compose_cmd down -v || true
  if [[ $ENV_CREATED -eq 1 && "${STACK_VALIDATION_PRESERVE_ENV:-0}" != "1" ]]; then
    rm -f "$ENV_FILE"
  fi
}
trap 'cleanup $?' EXIT

compose_cmd up -d --remove-orphans

wait_for_http() {
  local url=$1
  local retries=${2:-36}
  local delay=${3:-5}

  for ((attempt = 1; attempt <= retries; attempt++)); do
    if curl --silent --show-error --fail "$url" > /dev/null; then
      echo "Endpoint healthy: $url"
      return 0
    fi
    echo "Waiting for $url ($attempt/$retries)"
    sleep "$delay"
  done

  echo "Timed out waiting for $url after $((retries * delay))s" >&2
  return 1
}

OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
wait_for_http "$OLLAMA_BASE_URL/api/version"

if ! compose_cmd exec -T ollama ollama --version > /dev/null; then
  echo "Failed to execute ollama CLI inside container" >&2
  exit 1
fi

echo "Stack validation succeeded"
