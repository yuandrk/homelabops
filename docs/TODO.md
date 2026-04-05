# Documentation TODO

**Last Updated**: 2026-04-05

## Performance & Operations

### Critical - Memory Overcommit on k3s-worker3

- [ ] Reduce memory limits (currently 125% overcommitted - 19.5GB limits on 16GB node)
  - [ ] Review Immich server limit (8Gi) - consider reducing to 6Gi
  - [ ] Add memory limits to open-webui (currently none, using 607Mi)
  - [ ] Add memory limits to open-webui-ollama (currently none)

### High - Workload Rebalancing

- [ ] Move Prometheus off Raspberry Pi nodes (1.5GB on k3s-worker1 with 4GB total)
- [ ] Rebalance pods: k3s-worker3 has 20+ pods, k3s-worker2 only 8

### Medium - Resource Limits

- [ ] Add limits to unbound pods: open-webui, open-webui-ollama, open-webui-pipelines, traefik, immich-valkey, alloy
- [ ] Optimize Loki chunks-cache (using 2.1GB memory)

### Node Version Alignment

- [ ] Upgrade k3s-worker1 and k3s-worker2 from v1.33.3 to v1.33.5

## Documentation Gaps

- [ ] Document Immich setup and configuration (photos.yuandrk.net)
- [ ] Document Loki + Alloy log aggregation stack
- [ ] Document NFS storage provisioner setup
- [ ] Document backup and restore procedures
- [ ] Clean up stale ollama pods (2 ContainerStatusUnknown, 1 UnexpectedAdmissionError)
