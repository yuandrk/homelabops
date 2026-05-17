# Documentation TODO

**Last Updated**: 2026-04-05

## Performance & Operations

### Critical - Memory Overcommit on k3s-worker3

- [ ] Reduce memory limits on k3s-worker3
  - [ ] Review Immich server limit (8Gi) - consider reducing to 6Gi

### High - Workload Rebalancing

- [ ] Move Prometheus off Raspberry Pi nodes (1.5GB on k3s-worker1 with 4GB total)
- [ ] Rebalance pods between workers

### Medium - Resource Limits

- [ ] Add limits to unbound pods: traefik, immich-valkey, alloy
- [ ] Optimize Loki chunks-cache (using 2.1GB memory)

### Node Version Alignment

- [ ] Upgrade k3s-worker1 and k3s-worker2 from v1.33.3 to v1.33.5

## Identity & Access

- [x] Integrate Headlamp with Okta via K3s OIDC
  - [x] Create Okta OIDC app for K3s API server
  - [x] Configure K3s `--kube-apiserver-arg` flags (`oidc-issuer-url`, `oidc-client-id`, `oidc-username-claim`, `oidc-groups-claim`)
  - [x] Map Okta user to K8s RBAC via ClusterRoleBinding (subject format: `https://integrator-7752059.okta.com#me@yuandrk.net`)
  - [x] Update Headlamp to use OIDC flow (PKCE enabled)
  - [ ] If 403 errors return: check `Authorization` header in DevTools Network tab on a failing request — verify Headlamp is sending the OIDC JWT (starts with `eyJ`), not the service account token

## Documentation Gaps

- [ ] Document Immich setup and configuration (photos.yuandrk.net)
- [ ] Document Loki + Alloy log aggregation stack
- [ ] Document NFS storage provisioner setup
- [ ] Document backup and restore procedures
