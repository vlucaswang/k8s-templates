#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need curl
need nc

mode="${VERIFY_LOCALHOST_MODE:-port-forward}"
started_port_forward=false

cleanup() {
  if [[ "${started_port_forward}" == "true" && "${KEEP_PORT_FORWARD:-false}" != "true" ]]; then
    "${ROOT_DIR}/scripts/stop-port-forward.sh" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

wait_for_tcp() {
  local host="$1"
  local port="$2"
  local name="$3"
  local timeout="${4:-60}"
  local start="${SECONDS}"

  while (( SECONDS - start < timeout )); do
    if nc -z "${host}" "${port}" >/dev/null 2>&1; then
      echo "${name}: tcp ${host}:${port} reachable"
      return
    fi
    sleep 2
  done

  echo "${name}: tcp ${host}:${port} not reachable" >&2
  exit 1
}

wait_for_http() {
  local url="$1"
  local name="$2"
  local host_header="${3:-}"
  local timeout="${4:-60}"
  local start="${SECONDS}"
  local status

  while (( SECONDS - start < timeout )); do
    if [[ -n "${host_header}" ]]; then
      status="$(curl -ksS -H "Host: ${host_header}" -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)"
    else
      status="$(curl -ksS -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)"
    fi
    if [[ "${status}" =~ ^(2|3|4)[0-9][0-9]$ ]]; then
      echo "${name}: http ${url} returned ${status}"
      return
    fi
    sleep 2
  done

  echo "${name}: http ${url} did not respond" >&2
  exit 1
}

case "${mode}" in
  loadbalancer)
    wait_for_http "${TEMPORAL_UI_URL:-http://localhost:8080/}" "Temporal UI via kgateway LoadBalancer" "temporal-ui.localhost"
    wait_for_tcp localhost "${TEMPORAL_FRONTEND_PORT:-7233}" "Temporal frontend via kgateway LoadBalancer"
    ;;
  port-forward)
    "${ROOT_DIR}/scripts/port-forward.sh"
    started_port_forward=true
    wait_for_http "${TEMPORAL_UI_URL:-http://localhost:8080/}" "Temporal UI via port-forward" "temporal-ui.localhost"
    wait_for_tcp localhost "${TEMPORAL_FRONTEND_PORT:-7233}" "Temporal frontend via port-forward"
    wait_for_http "${ARGOCD_URL:-https://localhost:8443/}" "Argo CD via port-forward"
    wait_for_tcp localhost "${REDIS_PORT:-6379}" "Redis via port-forward"
    wait_for_tcp localhost "${POSTGRES_PORT:-5432}" "Postgres via port-forward"
    ;;
  *)
    echo "unknown VERIFY_LOCALHOST_MODE=${mode}; expected loadbalancer or port-forward" >&2
    exit 1
    ;;
esac
