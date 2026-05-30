#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_versions
need kubectl

echo "Gateway services:"
kubectl get svc -n kgateway-system -o wide || true

if command -v docker >/dev/null 2>&1; then
  echo
  echo "LoadBalancer containers and host mappings:"
  docker ps --filter name=kindccm --format 'table {{.Names}}\t{{.Ports}}' || true
fi

echo
echo "Temporal UI via kgateway:"
echo "  curl -H 'Host: temporal-ui.localhost' http://localhost:<mapped-http-port>/"

echo
echo "Temporal frontend via kgateway:"
echo "  temporal --address localhost:<mapped-grpc-port> operator cluster health"
echo "  Use Host/authority temporal.localhost if your client supports it."

echo
echo "Argo CD localhost helper:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8443:443"
echo "  https://localhost:8443"

echo
echo "Redis localhost helper:"
echo "  kubectl -n redis port-forward svc/redis 6379:6379"
echo "  redis-cli -h localhost -p 6379 ping"

echo
echo "cloud-provider-kind note:"
echo "  Start cloud-provider-kind with -enable-lb-port-mapping on macOS/Windows to expose LoadBalancer services on localhost."
