#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions

if command -v ruby >/dev/null 2>&1; then
  yaml_files=()
  while IFS= read -r file; do
    yaml_files+=("${file}")
  done < <(find "${ROOT_DIR}" \
    -path "${ROOT_DIR}/.git" -prune -o \
    -path "${ROOT_DIR}/tmp" -prune -o \
    \( -name '*.yaml' -o -name '*.yml' \) -print)
  ruby -ryaml -e 'ARGV.each { |f| YAML.load_stream(File.read(f)) }' "${yaml_files[@]}"
else
  echo "ruby not found; skipping YAML syntax validation"
fi

if command -v kubectl >/dev/null 2>&1; then
  for app in "${ROOT_DIR}"/gitops/apps/*; do
    [[ -d "${app}" ]] || continue
    kubectl kustomize "${app}" >/dev/null
  done
else
  echo "kubectl not found; skipping Kustomize validation"
fi

if command -v helm >/dev/null 2>&1; then
  helm repo add cilium https://helm.cilium.io >/dev/null
  helm repo update cilium >/dev/null
  helm template cilium cilium/cilium \
    --namespace kube-system \
    --version "${CILIUM_VERSION}" \
    --values "${ROOT_DIR}/bootstrap/cilium-values.yaml" >/dev/null
else
  echo "helm not found; skipping Helm values validation"
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${ROOT_DIR}"/scripts/*.sh "${ROOT_DIR}"/tests/scenarios/*.sh
else
  echo "shellcheck not found; skipping shell lint"
fi

echo "validate completed"
