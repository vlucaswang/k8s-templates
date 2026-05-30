#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions

pid_file="${ROOT_DIR}/tmp/port-forwards.pid"

if [[ ! -f "${pid_file}" ]]; then
  exit 0
fi

while IFS= read -r pid; do
  [[ -n "${pid}" ]] || continue
  kill "${pid}" >/dev/null 2>&1 || true
done < "${pid_file}"

rm -f "${pid_file}"
