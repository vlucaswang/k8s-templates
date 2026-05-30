#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need kubectl

wait_for_app() {
  local app="$1"
  local timeout="${2:-900}"
  local start="${SECONDS}"

  while (( SECONDS - start < timeout )); do
    local sync_status
    local health_status
    sync_status="$(kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
      echo "application ${app} is Synced/Healthy"
      return
    fi
    sleep 5
  done

  kubectl -n "${ARGOCD_NAMESPACE}" describe application "${app}" >&2 || true
  echo "application ${app} did not become Synced/Healthy" >&2
  exit 1
}

for app in \
  gateway-api-crds \
  kgateway-crds \
  kgateway \
  cnpg-operator \
  temporal-database \
  redis \
  temporal \
  temporal-edge; do
  wait_for_app "${app}"
done

kubectl wait --for=condition=Available deployment -n cnpg-system cnpg-cloudnative-pg --timeout=10m
kubectl wait --for=condition=Available deployment -n kgateway-system kgateway --timeout=10m
kubectl wait --for=condition=Available deployment -n kgateway-system temporal-local --timeout=10m
kubectl wait --for=condition=Ready cluster/postgres -n temporal --timeout=10m
kubectl wait --for=condition=Available deployment -n redis redis --timeout=10m
kubectl wait --for=condition=Available deployment -n temporal temporal-frontend --timeout=15m
kubectl wait --for=condition=Available deployment -n temporal temporal-history --timeout=15m
kubectl wait --for=condition=Available deployment -n temporal temporal-matching --timeout=15m
kubectl wait --for=condition=Available deployment -n temporal temporal-worker --timeout=15m
kubectl wait --for=condition=Available deployment -n temporal temporal-web --timeout=15m
kubectl wait --for=condition=Programmed gateway/temporal-local -n kgateway-system --timeout=10m
kubectl wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
  httproute/temporal-ui -n temporal --timeout=10m
kubectl wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
  grpcroute/temporal-frontend -n temporal --timeout=10m

if [[ "${SKIP_LOADBALANCER_WAIT:-false}" != "true" ]]; then
  start="${SECONDS}"
  while (( SECONDS - start < 600 )); do
    lb_endpoint="$(kubectl -n kgateway-system get service temporal-local \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    if [[ -n "${lb_endpoint}" ]]; then
      echo "service temporal-local LoadBalancer endpoint: ${lb_endpoint}"
      break
    fi
    sleep 5
  done
  if [[ -z "${lb_endpoint:-}" ]]; then
    kubectl -n kgateway-system get service temporal-local -o wide >&2 || true
    echo "service temporal-local did not receive a LoadBalancer endpoint" >&2
    exit 1
  fi
fi

kubectl get applications -n "${ARGOCD_NAMESPACE}" || true
kubectl get pods -A
