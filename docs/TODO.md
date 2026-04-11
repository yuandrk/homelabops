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

## Documentation Gaps

- [ ] Document Immich setup and configuration (photos.yuandrk.net)
- [ ] Document Loki + Alloy log aggregation stack
- [ ] Document NFS storage provisioner setup
- [ ] Document backup and restore procedures
