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

if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" >/dev/null 2>&1; then
  echo "cloud-provider-kind already running with pid $(cat "${pid_file}")"
  exit 0
fi

nohup cloud-provider-kind --enable-lb-port-mapping >"${log_file}" 2>&1 &
echo "$!" > "${pid_file}"
echo "cloud-provider-kind started with pid $(cat "${pid_file}")"
echo "logs: ${log_file}"
