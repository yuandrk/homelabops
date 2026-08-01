# Documentation TODO

**Last Updated**: 2026-06-11

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

- [x] Align node versions — all three nodes upgraded to k3s v1.34.9+k3s1 on 2026-08-01
  (k3s-worker2 was decommissioned May 2026). Upgrade by binary swap, not the install
  script: `--cluster-cidr`, `--service-cidr` and one `--tls-san` live only in the systemd
  unit and would be lost. Pre-upgrade backups are in `/root/k3s-backup-pre-1.34` on the
  master and `/root/k3s-v1.33.*.bin` on the workers.
- [ ] Consider Flux v2.9.x now that the K8s >= v1.34.1 floor is met (PR #30 was closed
  while the cluster was still on v1.33, so Renovate will not re-raise it)

## Identity & Access

- [x] Integrate Headlamp with Okta via K3s OIDC
  - [x] Create Okta OIDC app for K3s API server
  - [x] Configure K3s `--kube-apiserver-arg` flags (`oidc-issuer-url`, `oidc-client-id`, `oidc-username-claim`, `oidc-groups-claim`)
  - [x] Map Okta user to K8s RBAC via ClusterRoleBinding (subject format: `https://okta.yuandrk.net#me@yuandrk.net`)
  - [x] Update Headlamp to use OIDC flow (PKCE enabled)
  - [ ] If 403 errors return: check `Authorization` header in DevTools Network tab on a failing request — verify Headlamp is sending the OIDC JWT (starts with `eyJ`), not the service account token

## Documentation Gaps

- [ ] Document Immich setup and configuration (photos.yuandrk.net)
- [ ] Document Loki + Alloy log aggregation stack
- [ ] Document NFS storage provisioner setup
- [ ] Document backup and restore procedures
