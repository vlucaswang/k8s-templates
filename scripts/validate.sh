#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
use_public_docker_config
use_public_helm_config

if command -v ruby >/dev/null 2>&1; then
  yaml_files=()
  while IFS= read -r file; do
    yaml_files+=("${file}")
  done < <(find "${ROOT_DIR}" \
    -path "${ROOT_DIR}/.git" -prune -o \
    -path "${ROOT_DIR}/tmp" -prune -o \
    -path "${ROOT_DIR}/platform/charts/*/templates" -prune -o \
    \( -name '*.yaml' -o -name '*.yml' \) -print)
  ruby -ryaml -e 'ARGV.each { |f| YAML.load_stream(File.read(f)) }' "${yaml_files[@]}"
else
  echo "ruby not found; skipping YAML syntax validation"
fi

if command -v kubectl >/dev/null 2>&1; then
  for app in "${ROOT_DIR}"/gitops/apps/*; do
    [[ -d "${app}" ]] || continue
    [[ -f "${app}/kustomization.yaml" ]] || continue
    kubectl kustomize "${app}" >/dev/null
  done
else
  echo "kubectl not found; skipping Kustomize validation"
fi

if command -v helm >/dev/null 2>&1; then
  helm repo add cilium https://helm.cilium.io >/dev/null
  helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null
  helm repo add temporal https://go.temporal.io/helm-charts >/dev/null
  helm repo update cilium >/dev/null
  helm repo update cnpg >/dev/null
  helm repo update temporal >/dev/null
  helm template cilium cilium/cilium \
    --namespace kube-system \
    --version "${CILIUM_VERSION}" \
    --values "${ROOT_DIR}/bootstrap/cilium-values.yaml" >/dev/null
  helm template cnpg cnpg/cloudnative-pg \
    --namespace cnpg-system \
    --version "${CLOUDNATIVEPG_CHART_VERSION}" \
    --values "${ROOT_DIR}/gitops/helm-values/cnpg-operator.yaml" >/dev/null
  helm template temporal temporal/temporal \
    --namespace temporal \
    --version "${TEMPORAL_CHART_VERSION}" \
    --values "${ROOT_DIR}/gitops/helm-values/temporal.yaml" >/dev/null
  helm template kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds \
    --namespace kgateway-system \
    --version "${KGATEWAY_VERSION}" \
    --values "${ROOT_DIR}/gitops/helm-values/kgateway-crds.yaml" >/dev/null
  helm template kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
    --namespace kgateway-system \
    --version "${KGATEWAY_VERSION}" \
    --values "${ROOT_DIR}/gitops/helm-values/kgateway.yaml" >/dev/null
  helm template redis "${ROOT_DIR}/platform/charts/redis" \
    --namespace redis >/dev/null
  helm template redis "${ROOT_DIR}/platform/charts/redis" \
    --namespace redis \
    --values "${ROOT_DIR}/gitops/catalog-values/redis-local.yaml" >/dev/null
else
  echo "helm not found; skipping Helm values validation"
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${ROOT_DIR}"/scripts/*.sh "${ROOT_DIR}"/tests/scenarios/*.sh
else
  echo "shellcheck not found; skipping shell lint"
fi

echo "validate completed"
