#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib.sh
source "${SCRIPT_DIR}/../../scripts/lib.sh"

load_versions
need kubectl

kubectl -n temporal wait --for=condition=Available deployment/temporal-frontend --timeout=15m
kubectl -n temporal wait --for=condition=Available deployment/temporal-web --timeout=10m
kubectl -n redis wait --for=condition=Available deployment/redis --timeout=5m

pod="temporal-smoke-$(date +%s)"
kubectl -n temporal run "${pod}" \
  --image="${TEMPORAL_ADMIN_TOOLS_IMAGE}" \
  --restart=Never \
  --rm \
  --attach \
  --pod-running-timeout=5m \
  --command -- sh -ec '
    temporal operator namespace list --address temporal-frontend:7233 >/tmp/temporal-namespaces.txt
    cat /tmp/temporal-namespaces.txt
  '
