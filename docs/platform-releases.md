# Platform Releases

This repository is the shared platform repo. Customer config repos consume it by
pinning a platform release tag such as `platform-v1.4.0`.

## Release Contract

Platform releases include shared behavior that should be identical across
clusters and clouds:

- `platform/catalog.yaml` chart metadata
- Helm chart defaults
- Cilium NetworkPolicies
- Prometheus ServiceMonitors
- cert-manager annotation conventions
- Argo CD ApplicationSet patterns

Cluster-specific values do not belong in a platform release. Keep domains, node
counts, cloud IDs, account roles, and TLS provider fields in each customer
config repo.

## Create A Release

Run local validation and create an annotated release tag:

```sh
make release-platform TAG=platform-v1.4.0
git push origin platform-v1.4.0
```

The helper refuses to release from a dirty working tree and validates the tag
format before running the repository validation suite.

## Adopt A Release

In each customer config repo, use the TypeScript CLI:

```sh
npx github:vlucaswang/temporal-gitops-config-cli platform:bump \
  --repo ./customer-temporal-config \
  --platform-version platform-v1.4.0
```

That updates:

- `platform-release.yaml`
- `argocd/root-applicationset.yaml`

Open the config repo PR, let Argo CD reconcile UAT, run Temporal scenario tests,
then promote the same platform version to Prod.

## Example Shared Fix

If a Prometheus duplicate timestamps issue is fixed in this platform repo:

1. Commit the ServiceMonitor or chart-default fix here.
2. Tag `platform-v1.4.1`.
3. Bump each customer config repo to `platform-v1.4.1`.
4. Argo CD reconciles the fix into AWS, GCP, Azure, and bare-metal clusters from
   the same platform source.
