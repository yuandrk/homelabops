# DevOps Workflow & Development Tooling

**Repository**: HomelabOps GitOps Infrastructure  
**Branch Strategy**: Main branch with direct commits + FluxCD auto-sync  
**Quality Gates**: Pre-commit hooks, linting, and planned CI/CD automation

---

## 🔧 Development Tooling (`pre‑commit` & linters)

### Installed hooks (active for **ansible/** only)

| Category   | Hook(s)                                                                                                                                           | Purpose                                               |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Hygiene    | `end-of-file-fixer`, `check-added-large-files`, `mixed-line-ending`, `check-merge-conflict`, `destroyed-symlinks`, `check-symlinks`, `check-json` | Catch general repo issues before they land in Git     |
| YAML       | `check-yaml` (+ `--allow-multiple-documents`)                                                                                                     | Basic YAML validity – but limited to `ansible/` paths |
| YAML style | `yamllint`                                                                                                                                        | Enforces indentation & style within `ansible/`        |
| Ansible    | `ansible-lint`                                                                                                                                    | Static analysis of playbooks & roles (`ansible/`)     |
| Commits    | `commitizen`                                                                                                                                      | Conventional‑commit message format                    |

### Configuration Files

```yaml
# .pre-commit-config.yaml (excerpt)
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v5.0.0
  hooks:
    - id: check-yaml
      args: ["--allow-multiple-documents"]
      files: '^ansible/.*\.(ya?ml)$'
# ...
- repo: https://github.com/ansible/ansible-lint
  hooks:
    - id: ansible-lint
      files: '^ansible/.*\.(ya?ml)$'
```

```yaml
# .ansible-lint (excerpt)
profile: production
skip_list: [yaml, fqcn-builtins, experimental, no-changed-when]
exclude_paths:
  - ansible/examples/
  - Ansible/          # legacy dir excluded
```

---

## 🚀 Current GitOps Workflow

### Repository Structure
- **Main branch**: Single branch strategy with direct commits
- **FluxCD**: Watches `main` branch, auto-deploys from `./clusters/prod`
- **Quality gates**: Pre-commit hooks ensure code quality before commits

### Deployment Flow
1. **Local Development**: Changes made to infrastructure/apps
2. **Pre-commit Validation**: Automatic linting, formatting, validation
3. **Git Commit**: Push to main branch (conventional commit messages)
4. **FluxCD Sync**: Automatic reconciliation every 10m/1m intervals
5. **K3s Deployment**: Changes applied to cluster automatically

### Current Scope
- ✅ **Ansible**: Full linting and validation pipeline
- ⏳ **Kubernetes**: Basic YAML validation (expansion planned)
- ⏳ **Terraform**: No validation yet (future enhancement)
- ⏳ **Documentation**: No markdown linting (future enhancement)

---

## 🛠️ Setup Instructions

### Installing on Fresh Machine
```bash
# Install pre-commit
pipx install pre-commit

# Setup git hooks
pre-commit install          # installs git hooks
pre-commit run --all-files  # first pass validation
```

*(Requires Python ≥3.10; YAML/Ansible dependencies installed automatically)*

---

## 🏗️ Planned CI/CD Enhancements

### GitHub Actions Integration
```yaml
# .github/workflows/pre-commit.yml (planned)
name: pre-commit
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pre-commit/action@v3.0.1
```

### Expanded Validation Scope
- **Kubernetes manifests**: Add `kubeconform` or `kube-linter` with `files: '^clusters/'`
- **Flux custom resources**: Use `fluxcd/flux-lint` Docker image as hook
- **Terraform**: Add `terraform validate` and `tflint` for IaC validation
- **Markdown**: `markdownlint-cli` for documentation consistency
- **Security**: `checkov` or `trivy` for security scanning

### Pipeline Stages (Future)
1. **Lint & Format**: Pre-commit hooks + expanded validation
2. **Security Scan**: Infrastructure and container security checks
3. **Test**: Ansible syntax validation, Terraform plan verification
4. **Deploy**: Enhanced FluxCD integration with notifications

---

## 📝 Current Limitations & Improvements

### Current State
- Pre-commit hooks limited to `ansible/` directory only
- No automated testing of Ansible playbooks
- No Terraform validation in CI pipeline
- Manual deployment verification

### Planned Improvements
- Expand pre-commit scope to entire repository
- Add GitHub Actions for automated validation
- Implement deployment notifications (Slack/Discord)
- Add automated backup verification for critical changes
- Integrate with Renovate for dependency updates

---

## 🔄 Conventional Commits

Using `commitizen` for standardized commit messages:

```bash
# Commit types
feat:     New feature
fix:      Bug fix
docs:     Documentation changes
style:    Code style changes
refactor: Code refactoring
chore:    Maintenance tasks
```

**Examples**:
- `feat: add pgAdmin deployment to K3s cluster`
- `fix: update Pi-hole Cloudflare tunnel port from 80 to 8081`
- `docs: update Ansible documentation for current setup`
- `chore: refactor directory structure for GitOps standards`

---

## 🧠 **Prompt Context (LLM)**
HomelabOps repository uses a **single-branch GitOps workflow** with main branch and FluxCD auto-sync. Pre-commit hooks provide quality gates for Ansible code specifically, with plans to expand coverage to Kubernetes manifests, Terraform, and documentation.

The repository follows **conventional commit** standards and is structured for **GitOps best practices** with clear separation of applications, infrastructure, and cluster configurations. Future CI/CD enhancements will add automated validation, security scanning, and deployment notifications.

Development workflow prioritizes **infrastructure as code** principles with automated deployment via FluxCD, while maintaining code quality through pre-commit hooks and planned GitHub Actions integration.
