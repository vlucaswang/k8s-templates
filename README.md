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

## Cleanup

```sh
make delete
```

## Notes

The first bootstrap has dependency ordering that can take several minutes: CNPG must install its CRDs, PostgreSQL must initialize, Temporal schema jobs must run, and then Temporal services become ready. Argo CD automated sync retries handle transient ordering failures.
