#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need cloud-provider-kind
use_public_docker_config

mkdir -p "${ROOT_DIR}/tmp"
pid_file="${ROOT_DIR}/tmp/cloud-provider-kind.pid"
log_file="${ROOT_DIR}/tmp/cloud-provider-kind.log"
cloud_provider_kind_bin="$(command -v cloud-provider-kind)"

if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" >/dev/null 2>&1; then
  echo "cloud-provider-kind already running with pid $(cat "${pid_file}")"
  exit 0
fi

start_cloud_provider_kind() {
  if [[ "${1:-}" == "sudo" ]]; then
    nohup sudo -n env "DOCKER_CONFIG=${DOCKER_CONFIG}" \
      "${cloud_provider_kind_bin}" --enable-lb-port-mapping >"${log_file}" 2>&1 &
  else
    nohup "${cloud_provider_kind_bin}" --enable-lb-port-mapping >"${log_file}" 2>&1 &
  fi
  echo "$!" > "${pid_file}"
}

start_cloud_provider_kind
sleep 2

if ! kill -0 "$(cat "${pid_file}")" >/dev/null 2>&1; then
  if grep -q 'please run this again with .*sudo' "${log_file}" && sudo -n true >/dev/null 2>&1; then
    start_cloud_provider_kind sudo
    sleep 2
  fi
fi

if ! kill -0 "$(cat "${pid_file}")" >/dev/null 2>&1; then
  cat "${log_file}" >&2
  echo "cloud-provider-kind failed to stay running." >&2
  echo "On macOS, run this target from a shell with sudo privileges or start cloud-provider-kind manually with --enable-lb-port-mapping." >&2
  exit 1
fi

echo "cloud-provider-kind started with pid $(cat "${pid_file}")"
echo "logs: ${log_file}"
