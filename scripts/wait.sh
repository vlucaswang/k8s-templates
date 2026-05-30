#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need kubectl

kubectl wait --for=condition=Available deployment -n kgateway-system --all --timeout=10m || true
kubectl wait --for=condition=Ready cluster/postgres -n temporal --timeout=10m || true
kubectl wait --for=condition=Ready pod -n redis -l app.kubernetes.io/name=redis --timeout=10m || true
kubectl wait --for=condition=Available deployment -n temporal --all --timeout=15m || true

kubectl get applications -n "${ARGOCD_NAMESPACE}" || true
kubectl get pods -A
