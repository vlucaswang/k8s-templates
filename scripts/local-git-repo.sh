#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need git

mkdir -p "${ROOT_DIR}/tmp"

repo_name="${LOCAL_GIT_REPO_NAME:-temporal-kind-gitops.git}"
host_name="${LOCAL_GIT_HOST:-host.docker.internal}"
port="${LOCAL_GIT_PORT:-9418}"
bare_repo="${ROOT_DIR}/tmp/${repo_name}"
pid_file="${ROOT_DIR}/tmp/git-daemon.pid"
log_file="${ROOT_DIR}/tmp/git-daemon.log"

if ! git -C "${ROOT_DIR}" diff --quiet --exit-code || ! git -C "${ROOT_DIR}" diff --cached --quiet --exit-code; then
  echo "working tree has uncommitted changes; commit them before serving the local GitOps repo" >&2
  exit 1
fi

rm -rf "${bare_repo}"
git clone --bare "${ROOT_DIR}" "${bare_repo}" >/dev/null
touch "${bare_repo}/git-daemon-export-ok"

if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" >/dev/null 2>&1; then
  kill "$(cat "${pid_file}")"
fi

nohup git daemon \
  --reuseaddr \
  --base-path="${ROOT_DIR}/tmp" \
  --export-all \
  --listen=0.0.0.0 \
  --port="${port}" \
  --informative-errors \
  --verbose >"${log_file}" 2>&1 &
echo "$!" > "${pid_file}"

echo "git://${host_name}:${port}/${repo_name}"
