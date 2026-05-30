#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need kubectl

mkdir -p "${ROOT_DIR}/tmp"
pid_file="${ROOT_DIR}/tmp/port-forwards.pid"
log_dir="${ROOT_DIR}/tmp/port-forwards"

"${ROOT_DIR}/scripts/stop-port-forward.sh" >/dev/null 2>&1 || true
mkdir -p "${log_dir}"
: > "${pid_file}"

start_forward() {
  local namespace="$1"
  local resource="$2"
  local ports="$3"
  local name="$4"

  nohup kubectl -n "${namespace}" port-forward "${resource}" "${ports}" >"${log_dir}/${name}.log" 2>&1 </dev/null &
  echo "$!" >> "${pid_file}"
}

start_forward kgateway-system svc/temporal-local 7233:7233 temporal-frontend
start_forward kgateway-system svc/temporal-local 8080:8080 temporal-ui
start_forward "${ARGOCD_NAMESPACE}" svc/argocd-server 8443:443 argocd
start_forward redis svc/redis 6379:6379 redis
start_forward temporal svc/postgres-rw 5432:5432 postgres

sleep 2
while IFS= read -r pid; do
  if ! kill -0 "${pid}" >/dev/null 2>&1; then
    echo "a port-forward failed; logs are in ${log_dir}" >&2
    exit 1
  fi
done < "${pid_file}"

echo "local port-forwards started:"
echo "  Temporal frontend: localhost:7233"
echo "  Temporal UI:       http://localhost:8080"
echo "  Argo CD:           https://localhost:8443"
echo "  Redis:             localhost:6379"
echo "  Postgres:          localhost:5432"
echo "pids: ${pid_file}"
