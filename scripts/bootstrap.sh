#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need kind
need kubectl
need helm
use_public_docker_config

mkdir -p /tmp/temporal-kind

if ! kind_cluster_exists; then
  kind create cluster --config "${ROOT_DIR}/kind/cluster.yaml" --image "${KIND_NODE_IMAGE}"
else
  echo "kind cluster ${CLUSTER_NAME} already exists"
fi

kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

if [[ "${START_CLOUD_PROVIDER_KIND:-true}" == "true" ]]; then
  if ! "${ROOT_DIR}/scripts/cloud-provider-kind.sh"; then
    if [[ "${REQUIRE_CLOUD_PROVIDER_KIND:-false}" == "true" ]]; then
      exit 1
    fi
    echo "cloud-provider-kind did not start; continuing bootstrap without LoadBalancer port mapping." >&2
    echo "Run cloud-provider-kind with sudo, or use: SKIP_LOADBALANCER_WAIT=true make wait && make port-forward" >&2
  fi
fi

helm repo add cilium https://helm.cilium.io >/dev/null
helm repo update cilium >/dev/null
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version "${CILIUM_VERSION}" \
  --values "${ROOT_DIR}/bootstrap/cilium-values.yaml" \
  --wait \
  --timeout 10m

kubectl -n kube-system rollout status ds/cilium --timeout=10m
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=10m

kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n "${ARGOCD_NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-applicationset-controller --timeout=10m
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-repo-server --timeout=10m
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-server --timeout=10m

if [[ "${REPO_URL}" == *"vlucaswang"* ]]; then
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    REPO_URL="https://github.com/${GITHUB_REPOSITORY}.git"
  elif git -C "${ROOT_DIR}" remote get-url origin >/dev/null 2>&1; then
    REPO_URL="$(git -C "${ROOT_DIR}" remote get-url origin)"
  else
    REPO_URL="$("${ROOT_DIR}/scripts/local-git-repo.sh")"
  fi
fi

rendered_argocd="$(mktemp -d)"
trap 'rm -rf "${rendered_argocd}"' EXIT
for file in "${ROOT_DIR}"/argocd/*.yaml; do
  sed \
    -e "s#REPO_URL_PLACEHOLDER#${REPO_URL}#g" \
    -e "s#REPO_REVISION_PLACEHOLDER#${REPO_REVISION}#g" \
    "${file}" > "${rendered_argocd}/$(basename "${file}")"
done

kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${rendered_argocd}/project.yaml"
kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${rendered_argocd}/helm-applicationset.yaml"
kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${rendered_argocd}/kustomize-applicationset.yaml"
kubectl -n "${ARGOCD_NAMESPACE}" annotate applicationset temporal-kind-helm \
  bootstrap.temporal-kind/reconcile-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
kubectl -n "${ARGOCD_NAMESPACE}" annotate applicationset temporal-kind-kustomize \
  bootstrap.temporal-kind/reconcile-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite

echo "Bootstrap submitted. Run: make wait"
