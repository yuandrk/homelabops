# Documentation TODO List

**Last Updated**: 2025-11-04
**Generated From**: Documentation Audit

This document tracks all documentation improvements, additions, and fixes needed for the homelabops repository.

---

## 🔴 CRITICAL PRIORITY

### Immediate Fixes (Week 1)

- [x] **Fix filename typo**: Rename `docs/Network/Device shatpshoot.md` → `docs/Network/Device-Snapshot.md`
- [x] **Fix hardcoded paths** - Using `${KUBECONFIG:-"./terraform/kube/kubeconfig"}` pattern
  - [x] `docs/Monitoring/Monitoring-Troubleshooting.md` - Uses environment variable pattern
  - [x] `docs/FluxCD/FluxCD-Health-Monitoring.md` - Uses environment variable pattern
  - [x] `docs/Network/Complete-Network-Diagram.md` - No hardcoded paths found

### Missing Service Documentation (Week 1)

- [ ] **Create `docs/Applications/` directory**
- [ ] **Document n8n** - Create `docs/Applications/n8n-Setup.md`
  - [ ] Access URL and credentials
  - [ ] Integration with other services
  - [ ] Webhook configuration
  - [ ] Backup/restore procedures
  - [ ] Common workflows/examples
- [ ] **Document ActualBudget** - Create `docs/Applications/ActualBudget-Setup.md`
  - [ ] Access URL
  - [ ] Initial setup
  - [ ] Backup configuration
  - [ ] Data import/export

---

## 🟡 HIGH PRIORITY

### Operations Documentation (Week 2)

- [ ] **Migration databases to another node** find approach
- [ ] **Create `docs/Operations/` directory**
- [ ] **Backup Strategy** - Create `docs/Operations/Backup-Strategy.md`
  - [ ] What's backed up (databases, configs, PVs)
  - [ ] Backup schedule and retention
  - [ ] Restore procedures
  - [ ] Testing backup validity
  - [ ] Off-site backup configuration
- [ ] **Incident Response** - Create `docs/Operations/Incident-Response.md`
  - [ ] Common failure scenarios
  - [ ] Recovery procedures
  - [ ] Rollback strategies
  - [ ] Emergency contacts/escalation
  - [ ] Post-mortem template
- [ ] **Upgrade Guide** - Create `docs/Operations/Upgrade-Guide.md`
  - [ ] K3s version upgrades
  - [ ] FluxCD upgrades
  - [ ] Application upgrades
  - [ ] Pre-upgrade checklist
  - [ ] Rollback procedures

### Security Documentation (Week 2)

- [ ] **Create `docs/Security/` directory**
- [ ] **Security Hardening** - Create `docs/Security/Security-Hardening.md`
  - [ ] Current security posture assessment
  - [ ] Network security (firewall rules, network policies)
  - [ ] Secret management best practices
  - [ ] SSL/TLS configuration
  - [ ] Security audit checklist
  - [ ] UFW configuration recommendations
- [ ] **RBAC Guide** - Create `docs/Security/RBAC-Guide.md`
  - [ ] Current ServiceAccounts and permissions
  - [ ] Principle of least privilege
  - [ ] Creating limited-access tokens
  - [ ] Audit logging

### Headlamp Plugin Documentation

- [ ] **Flux Plugin** - Create `docs/Headlamp/Flux-Plugin-Setup.md`
  - [ ] Plugin installation process (via init container)
  - [ ] Plugin directory structure
  - [ ] Troubleshooting plugin issues
  - [ ] Plugin configuration

---

## 🟢 MEDIUM PRIORITY

### Central Documentation Hub (Week 3)

- [ ] **Create comprehensive index** - Create `docs/README.md`
  - [ ] Quick start guide (most common tasks)
  - [ ] Documentation map by role (admin, developer, user)
  - [ ] Troubleshooting decision tree
  - [ ] FAQ section
  - [ ] Contribution guidelines for docs

### Architecture Documentation (Week 3)

- [ ] **Service Dependencies** - Create `docs/Architecture/Service-Dependencies.md`
  - [ ] Mermaid diagram showing service relationships
  - [ ] Database dependencies
  - [ ] External dependencies (Cloudflare, AWS)
  - [ ] Critical path analysis
- [ ] **Resource Planning** - Create `docs/Architecture/Resource-Planning.md`
  - [ ] Current resource utilization
  - [ ] Capacity planning
  - [ ] Scaling guidelines
  - [ ] Performance benchmarks

### Development Workflow (Week 3)

- [ ] **Create `docs/Development/` directory**
- [ ] **Local Development** - Create `docs/Development/Local-Setup.md`
  - [ ] Setting up local kubectl access
  - [ ] Testing changes before deployment
  - [ ] Using kind/k3d for local testing
  - [ ] Pre-commit hooks usage
- [ ] **Contributing Guide** - Create `CONTRIBUTING.md` (root level)
  - [ ] How to contribute
  - [ ] Documentation standards
  - [ ] Commit message conventions
  - [ ] PR process

### Monitoring and Observability (Week 3)

- [ ] **Alert Runbooks** - Create `docs/Monitoring/Alert-Runbooks.md`
  - [ ] Document each alert with:
    - What it means
    - Why it fires
    - How to investigate
    - How to resolve
    - When to escalate
- [ ] **Dashboard Guide** - Create `docs/Monitoring/Dashboard-Guide.md`
  - [ ] Grafana dashboard overview
  - [ ] Key metrics to watch
  - [ ] Custom dashboard creation
  - [ ] Interpreting graphs

### Networking Documentation (Week 3)

- [ ] **DNS Configuration** - Create `docs/Network/DNS-Configuration.md`
  - [ ] Pi-hole configuration
  - [ ] CoreDNS configuration
  - [ ] Split-horizon DNS setup
  - [ ] DNS troubleshooting
- [ ] **Ingress Guide** - Create `docs/Network/Ingress-Guide.md`
  - [ ] Traefik configuration
  - [ ] Cloudflare Tunnel setup
  - [ ] Adding new services to external access
  - [ ] SSL certificate management

---

## 🚀 K3S CLUSTER PERFORMANCE OPTIMIZATION

**Last Assessed**: 2026-01-10

### Critical - Memory Overcommit on k3s-worker3

- [ ] **Reduce memory limits on k3s-worker3** (currently 125% overcommitted - 19.5GB limits on 16GB node)
  - [ ] Review Immich server limit (8Gi) - consider reducing to 6Gi
  - [ ] Add memory limits to open-webui (currently none, using 607Mi)
  - [ ] Add memory limits to open-webui-ollama (currently none)
  - [ ] Target: Keep total limits under 100% of allocatable memory

### High - Workload Rebalancing

- [ ] **Move monitoring workloads off Raspberry Pi nodes**
  - [ ] Prometheus (1.5GB) competing with other pods on k3s-worker1 (4GB total)
  - [ ] Consider scheduling Prometheus on k3s-master or k3s-worker3
  - [ ] Add node affinity for memory-intensive workloads to amd64 nodes

- [ ] **Optimize pod distribution**
  - [ ] k3s-worker3: 20+ pods (overloaded)
  - [ ] k3s-worker2: Only 8 pods (underutilized)
  - [ ] Consider using pod anti-affinity for better spread

### Medium - Add Missing Resource Limits

- [ ] **Configure resource limits for unbound pods**
  - [ ] `open-webui` (apps) - no limits, using 607Mi
  - [ ] `open-webui-ollama` (apps) - no limits
  - [ ] `open-webui-pipelines` (apps) - no limits
  - [ ] `traefik` (kube-system) - no limits
  - [ ] `immich-valkey` (apps) - no limits
  - [ ] `alloy` DaemonSet (monitoring) - no limits, using 150-167Mi per node

### Medium - Monitoring Stack Tuning

- [ ] **Reduce Prometheus resource usage**
  - [ ] Review scrape intervals (currently default)
  - [ ] Consider reducing retention period (currently 15d)
  - [ ] Evaluate disabling unused exporters/targets
  - [ ] Current usage: 279m CPU, 1.5GB memory

- [ ] **Optimize Loki stack**
  - [ ] loki-chunks-cache using 2.1GB memory
  - [ ] Review cache size configuration
  - [ ] Consider reducing log retention

### Node Version Alignment

- [ ] **Upgrade worker nodes to consistent K3s version**
  - [ ] k3s-master: v1.33.5+k3s1 ✓
  - [ ] k3s-worker1: v1.33.3+k3s1 (needs upgrade)
  - [ ] k3s-worker2: v1.33.3+k3s1 (needs upgrade)
  - [ ] k3s-worker3: v1.33.5+k3s1 ✓

---

## ⚙️ IMPROVEMENTS & CLEANUP

### Documentation Consolidation (Week 4)

- [ ] **Resolve duplicate monitoring guides**:
  - [ ] Option A: Rename to differentiate purpose
    - `Monitoring-Troubleshooting-Detailed.md` (comprehensive)
    - `Monitoring-Troubleshooting-Quick.md` (quick reference)
  - [ ] Option B: Merge into single guide with Quick Reference section at top
  - [ ] Add cross-references between related guides
- [ ] **Clean up planning documents**:
  - [ ] Archive `docs/Planning/headlamp-setup.md` (Headlamp is now deployed)
  - [ ] Review other planning docs for completion status

### Documentation Standards (Week 4)

- [ ] **Create `docs/.templates/` directory**
- [ ] **Create documentation templates**:
  - [ ] `service-setup-template.md`
  - [ ] `troubleshooting-template.md`
  - [ ] `architecture-doc-template.md`
  - [ ] `runbook-template.md`
- [ ] **Create style guide** - Create `docs/.style-guide.md`
  - [ ] File naming conventions
  - [ ] Heading structure
  - [ ] Code block formatting
  - [ ] Link format (relative vs absolute)
  - [ ] Date formats (YYYY-MM-DD)
  - [ ] Path references (use variables/relative paths)

### Automation (Week 4)

- [ ] **Documentation health check** - Create `tools/check-docs.sh`
  - [ ] Check for broken internal links
  - [ ] Find hardcoded paths
  - [ ] Identify files without "Last Updated" dates
  - [ ] Check for orphaned documentation
  - [ ] Validate markdown syntax
  - [ ] List undocumented services (compare apps/ with docs/)
- [ ] **Service inventory generator** - Create `tools/generate-service-inventory.sh`
  - [ ] Auto-generate list of deployed services
  - [ ] Create service dependency graph
  - [ ] Export current configuration as documentation
  - [ ] Generate resource usage reports

---

## 📝 ADDITIONAL IMPROVEMENTS

### Documentation Enhancements

- [ ] **Add "Last Updated" dates** to all documentation files
- [ ] **Add Table of Contents** to long documentation files (>200 lines)
- [ ] **Verify date accuracy** on `docs/Network/k3s-cluster-performance-2025-08-02.md`
- [ ] **Add diagrams** to complex service documentation
- [ ] **Create FAQ section** for common questions
- [ ] **Add troubleshooting sections** to all service setup guides

### Documentation Validation

- [ ] **Review all external links** for validity
- [ ] **Test all command examples** for accuracy
- [ ] **Validate all code snippets** for syntax errors
- [ ] **Ensure all referenced files exist**
- [ ] **Check consistency** of terminology across docs

---

## 🎯 Quick Wins (Do These First)

These can be completed in under 30 minutes and provide immediate value:

1. [x] Rename `Device shatpshoot.md` → `Device-Snapshot.md` (2 min) ✅
2. [x] Fix 3 hardcoded paths (10 min) ✅
3. [ ] Create `docs/Applications/` directory structure (2 min)
4. [ ] Create `docs/README.md` index skeleton (10 min)
5. [ ] Add "Last Updated" dates to undated documentation files (15 min)

**Estimated Remaining: ~27 minutes**

---

## 📊 Progress Tracking

### Overall Completion Status

- **Critical Priority**: 5/10 items completed (50%)
- **High Priority**: 0/12 items completed (0%)
- **Medium Priority**: 0/16 items completed (0%)
- **Improvements**: 0/10 items completed (0%)
- **Quick Wins**: 2/5 items completed (40%)

**Total**: 7/53 items completed

---

## 🔄 Review Schedule

- **Weekly Review**: Every Monday - Review progress and adjust priorities
- **Monthly Review**: First Monday of month - Assess overall documentation health
- **Quarterly Audit**: Full documentation audit and update this TODO list

---

## 📚 References

- **Documentation Audit Report**: See commit message for full audit findings
- **Documentation Style Guide**: `docs/.style-guide.md` (to be created)
- **Contributing Guide**: `CONTRIBUTING.md` (to be created)

---

**Note**: This TODO list is a living document. As items are completed, mark them with `[x]` and update the progress tracking section. Add new items as they are identified.
