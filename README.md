# k8s-templates

Local and CI Kubernetes templates for self-hosted Temporal workflow scenario tests.

The target cluster is:

- kind, with the default CNI disabled
- Cilium as the only CNI
- cloud-provider-kind for local `LoadBalancer` services
- kgateway for Gateway API traffic
- Argo CD ApplicationSets for platform and workload reconciliation
- CloudNativePG for PostgreSQL
- in-cluster Redis

## Prerequisites

Install:

- Docker or another kind-supported container runtime
- `kind`
- `kubectl`
- `helm`
- `cloud-provider-kind`

On macOS and Windows, `cloud-provider-kind` often needs elevated privileges to expose `LoadBalancer` services on localhost. The helper script starts it with `-enable-lb-port-mapping` by default.

## Quick Start

```sh
make bootstrap
make wait
make endpoints
make smoke
```

The bootstrap flow creates the kind cluster, installs Cilium, installs Argo CD, and applies the root ApplicationSets. Argo CD then reconciles the kgateway, CloudNativePG, Redis, Temporal, and edge-route manifests under `gitops/`.

If no `REPO_URL` is configured and the checkout has no `origin` remote, bootstrap starts a local read-only Git daemon and points Argo CD at `git://host.docker.internal/temporal-kind-gitops.git`. Set `LOCAL_GIT_HOST` if your kind nodes need a different host address.

## Local Access

Use:

```sh
make endpoints
```

The command prints localhost mappings for:

- Temporal UI through kgateway
- Temporal frontend through kgateway
- Argo CD through port-forward
- Redis through port-forward

If cloud-provider-kind cannot run locally because sudo is unavailable, use:

```sh
SKIP_LOADBALANCER_WAIT=true make wait
make port-forward
```

This exposes Temporal frontend on `localhost:7233`, Temporal UI on `localhost:8080`, Argo CD on `localhost:8443`, Redis on `localhost:6379`, and Postgres on `localhost:5432`.

To verify localhost access:

```sh
VERIFY_LOCALHOST_MODE=port-forward make verify-localhost
```

When cloud-provider-kind is running with load-balancer port mapping, the kgateway entry points can be checked directly:

```sh
VERIFY_LOCALHOST_MODE=loadbalancer make verify-localhost
```

## Cleanup

```sh
make delete
```

## Notes

The first bootstrap has dependency ordering that can take several minutes: CNPG must install its CRDs, PostgreSQL must initialize, Temporal schema jobs must run, and then Temporal services become ready. Argo CD automated sync retries handle transient ordering failures.
