#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need kubectl

kubectl get nodes -o wide
kubectl get pods -A
kubectl get applications -n "${ARGOCD_NAMESPACE}" || true
kubectl get gateway,httproute,grpcroute -A || true
