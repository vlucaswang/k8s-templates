# Repository Guidelines

This repository builds a local or CI kind cluster for Temporal workflow scenario testing.

## Scope

- The cluster is created by kind.
- kind must run without the default CNI; Cilium is the only CNI.
- `cloud-provider-kind` provides `LoadBalancer` behavior for services created by kgateway.
- Argo CD ApplicationSets manage the platform and workload resources after bootstrap.
- CloudNativePG provides PostgreSQL inside Kubernetes.
- Redis is provided inside Kubernetes.
- Local developer and GitHub Actions flows should use the same manifests.
- Public entry points must be reachable from localhost, either through the kgateway load balancer mapping or an explicit helper port-forward.

Bootstrap exceptions are intentionally small:

- Cilium is installed before Argo CD because Argo CD pods need cluster networking.
- Argo CD itself is installed before the root ApplicationSets can reconcile.
- Everything after those bootstrap steps should be represented in `gitops/` and reconciled by Argo CD.

## Layout

- `kind/` contains kind cluster configuration.
- `bootstrap/` contains values used before Argo CD takes over.
- `argocd/` contains the root ApplicationSet manifests applied by bootstrap.
- `gitops/` contains all resources managed by Argo CD.
- `scripts/` contains local and CI automation.
- `tests/` contains cluster validation and Temporal scenario smoke tests.

## Change Rules

- Keep commits small and logically grouped.
- Pin versions in `versions.env` and update usage in scripts/manifests together.
- Prefer Kustomize overlays or Helm values over generated YAML.
- Do not add a second CNI, kube-proxy replacement, ingress controller, or load-balancer implementation unless the user explicitly changes the architecture.
- Do not commit secrets with real credentials. Development-only credentials must be obvious and scoped to this local test cluster.

## Validation

Test locally before pushing to remote so GitHub Actions is used to confirm the change, not to find basic failures.

Before committing changes, run the strongest practical subset:

```sh
make validate
```

For cluster-affecting changes, run:

```sh
make bootstrap
make wait
make smoke
```

If a validation step cannot be run locally, note the exact command and the reason in the final response.
