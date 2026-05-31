#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release-platform.sh platform-vX.Y.Z

Creates an annotated platform release tag after local validation.
Push the tag after review:

  git push origin platform-vX.Y.Z
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

tag="${1:-}"
if [[ ! "${tag}" =~ ^platform-v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  usage >&2
  echo "invalid platform tag: ${tag}" >&2
  exit 1
fi

if [[ -n "$(git status --short)" ]]; then
  echo "working tree is not clean; commit or stash changes before releasing" >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  echo "tag already exists: ${tag}" >&2
  exit 1
fi

"${ROOT_DIR}/scripts/validate.sh"

git tag -a "${tag}" -m "${tag}"
echo "created ${tag}"
echo "push with: git push origin ${tag}"
