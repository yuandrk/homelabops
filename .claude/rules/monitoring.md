# Monitoring Stack

## Components

What runs, the selector labels that decide what Prometheus picks up, and what is still missing
are in [monitoring.md](../../docs/monitoring.md). Two things to keep in mind when touching it:

- **Alertmanager is disabled**, so alert rules notify no one. The custom `PrometheusRule` also
  lacks the `release: kube-prometheus-stack` label, which the default `ruleSelector` needs.
- **Grafana**: dashboards at `grafana.yuandrk.net`. `admin/flux` no longer works. Read the live
  credentials with:
  `kubectl get secret -n monitoring grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d`

## Quick Access

```bash
# Local Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Local Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

## Headlamp Dashboard

- URL: `headlamp.yuandrk.net`, login with Okta (OIDC through the k3s API server)
- Break-glass: a `headlamp-admin` ServiceAccount token, stored in 1Password (vault `homelab`, item
  `headlamp-token`) and synced to the `headlamp-token` Secret in `kube-system`. It **expired on
  2026-08-09**. The Okta app behind Headlamp's login could not be found either, see
  [access.md](../../docs/access.md#headlamps-okta-app-is-missing).
- Renew: `kubectl create token headlamp-admin -n kube-system --duration=8760h`, then paste it into
  the 1Password item (the cluster picks it up within 6h, see `docs/secrets.md`). Logins,
  break-glass and Okta details for every surface: [access.md](../../docs/access.md)
