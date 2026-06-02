#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

need helm

require_rendered_kind() {
  local rendered="$1"
  local chart="$2"
  local kind="$3"

  if ! grep -Eq "^kind: ${kind}$" "${rendered}"; then
    echo "platform chart ${chart} must render ${kind}" >&2
    exit 1
  fi
}

require_rendered_pattern() {
  local rendered="$1"
  local chart="$2"
  local pattern="$3"
  local description="$4"

  if ! grep -Eq "${pattern}" "${rendered}"; then
    echo "platform chart ${chart} must render ${description}" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

shopt -s nullglob
chart_dirs=("${ROOT_DIR}"/platform/charts/*)
if [[ ${#chart_dirs[@]} -eq 0 ]]; then
  echo "platform catalog has no charts" >&2
  exit 1
fi

for chart_dir in "${chart_dirs[@]}"; do
  [[ -d "${chart_dir}" ]] || continue
  [[ -f "${chart_dir}/Chart.yaml" ]] || continue

  chart_name="$(basename "${chart_dir}")"
  rendered_default="${tmp_dir}/${chart_name}-default.yaml"
  rendered_tls="${tmp_dir}/${chart_name}-tls.yaml"

  helm template "${chart_name}" "${chart_dir}" \
    --namespace "${chart_name}" > "${rendered_default}"

  require_rendered_kind "${rendered_default}" "${chart_name}" "CiliumNetworkPolicy"
  require_rendered_kind "${rendered_default}" "${chart_name}" "ServiceMonitor"
  require_rendered_pattern \
    "${rendered_default}" \
    "${chart_name}" \
    "app.kubernetes.io/part-of: temporal-platform" \
    "the shared platform label"

  helm template "${chart_name}" "${chart_dir}" \
    --namespace "${chart_name}" \
    --set tls.certManager.enabled=true \
    --set "tls.certManager.dnsNames[0]=${chart_name}.example.test" > "${rendered_tls}"

  require_rendered_kind "${rendered_tls}" "${chart_name}" "Certificate"
  require_rendered_pattern \
    "${rendered_tls}" \
    "${chart_name}" \
    "cert-manager.io/issuer-kind:" \
    "cert-manager issuer kind annotation"
  require_rendered_pattern \
    "${rendered_tls}" \
    "${chart_name}" \
    "cert-manager.io/issuer-name:" \
    "cert-manager issuer name annotation"
done

echo "platform catalog contracts validated"
