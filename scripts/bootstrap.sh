#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need kind
need kubectl
need helm

mkdir -p /tmp/temporal-kind

if ! kind_cluster_exists; then
  kind create cluster --config "${ROOT_DIR}/kind/cluster.yaml" --image "${KIND_NODE_IMAGE}"
else
  echo "kind cluster ${CLUSTER_NAME} already exists"
fi

kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

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
kubectl apply -n "${ARGOCD_NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-applicationset-controller --timeout=10m
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-repo-server --timeout=10m
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-server --timeout=10m

kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${ROOT_DIR}/argocd/"

echo "Bootstrap submitted. Run: make wait"
