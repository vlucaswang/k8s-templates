#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_versions() {
  set -a
  # shellcheck source=/dev/null
  source "${ROOT_DIR}/versions.env"
  set +a
}

need() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "missing required command: ${cmd}" >&2
    exit 1
  fi
}

kind_cluster_exists() {
  kind get clusters | grep -qx "${CLUSTER_NAME}"
}

use_public_docker_config() {
  if [[ -n "${DOCKER_CONFIG:-}" ]]; then
    return
  fi

  export DOCKER_CONFIG="${ROOT_DIR}/tmp/docker-config"
  mkdir -p "${DOCKER_CONFIG}"
  if [[ ! -f "${DOCKER_CONFIG}/config.json" ]]; then
    printf '{}\n' > "${DOCKER_CONFIG}/config.json"
  fi
}
