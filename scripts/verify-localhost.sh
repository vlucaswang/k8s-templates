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
  return 1
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
  return 1
}

mapped_host_port() {
  local container_port="$1"
  local regex=":([0-9]+)->${container_port}/tcp"
  local segment

  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi

  while IFS= read -r segment; do
    if [[ "${segment}" =~ ${regex} ]]; then
      echo "${BASH_REMATCH[1]}"
      return
    fi
  done < <(docker ps --format '{{.Ports}}' | tr ',' '\n')

  return 1
}

service_node_port() {
  local namespace="$1"
  local service="$2"
  local service_port="$3"

  kubectl -n "${namespace}" get service "${service}" \
    -o "jsonpath={.spec.ports[?(@.port==${service_port})].nodePort}"
}

loadbalancer_host_port() {
  local service_port="$1"
  local node_port

  if mapped_host_port "${service_port}"; then
    return
  fi

  node_port="$(service_node_port kgateway-system temporal-local "${service_port}")"
  if [[ -n "${node_port}" ]]; then
    mapped_host_port "${node_port}"
  else
    return 1
  fi
}

case "${mode}" in
  loadbalancer)
    ui_port="${TEMPORAL_UI_PORT:-8080}"
    frontend_port="${TEMPORAL_FRONTEND_PORT:-7233}"

    if ! wait_for_http "http://localhost:${ui_port}/" "Temporal UI via kgateway LoadBalancer" "temporal-ui.localhost" 10; then
      if mapped_ui_port="$(loadbalancer_host_port 8080)"; then
        ui_port="${mapped_ui_port}"
        wait_for_http "http://localhost:${ui_port}/" "Temporal UI via kgateway LoadBalancer mapped port" "temporal-ui.localhost"
      else
        echo "docker port mappings:" >&2
        docker ps --format 'table {{.Names}}\t{{.Ports}}' >&2 || true
        exit 1
      fi
    fi

    if ! wait_for_tcp localhost "${frontend_port}" "Temporal frontend via kgateway LoadBalancer" 10; then
      if mapped_frontend_port="$(loadbalancer_host_port 7233)"; then
        frontend_port="${mapped_frontend_port}"
        wait_for_tcp localhost "${frontend_port}" "Temporal frontend via kgateway LoadBalancer mapped port"
      else
        echo "docker port mappings:" >&2
        docker ps --format 'table {{.Names}}\t{{.Ports}}' >&2 || true
        exit 1
      fi
    fi
    ;;
  port-forward)
    "${ROOT_DIR}/scripts/port-forward.sh"
    started_port_forward=true
    wait_for_http "${TEMPORAL_UI_URL:-http://localhost:8080/}" "Temporal UI via port-forward" "temporal-ui.localhost" || exit 1
    wait_for_tcp localhost "${TEMPORAL_FRONTEND_PORT:-7233}" "Temporal frontend via port-forward" || exit 1
    wait_for_http "${ARGOCD_URL:-https://localhost:8443/}" "Argo CD via port-forward" || exit 1
    wait_for_tcp localhost "${REDIS_PORT:-6379}" "Redis via port-forward" || exit 1
    wait_for_tcp localhost "${POSTGRES_PORT:-5432}" "Postgres via port-forward" || exit 1
    ;;
  *)
    echo "unknown VERIFY_LOCALHOST_MODE=${mode}; expected loadbalancer or port-forward" >&2
    exit 1
    ;;
esac
