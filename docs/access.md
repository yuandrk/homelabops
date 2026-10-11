# Access

Who can log in where, and the way in when Okta is down.

## Identity provider

Okta, issuer `https://okta.yuandrk.net`. That is the org authorization server behind a custom
domain (`c21d197`), not `/oauth2/default`. Every OIDC client in the homelab uses this issuer.
Okta's own state (apps, groups, assignments) is not exported anywhere, so this page is its only
description.

## Login surfaces

| Surface | How you log in | Who gets in | Break-glass |
|---------|----------------|-------------|-------------|
| Kubernetes API through Headlamp, `headlamp.yuandrk.net` | Okta OIDC with PKCE. Headlamp hands the user's ID token to the k3s API server, which validates it (OIDC flags in `/etc/rancher/k3s/config.yaml` on k3s-master) | Okta: assignment to `homelab-admins`. Kubernetes: `ClusterRoleBinding/headlamp-okta-admin` makes `https://okta.yuandrk.net#me@yuandrk.net` cluster-admin. Anyone else authenticates and then gets 403 | The `headlamp-admin` ServiceAccount token ([probably expired](#the-headlamp-break-glass-token-has-probably-expired)), or `kubectl` on k3s-master |
| Kite, `kite.yuandrk.net` | Okta OIDC, Web app, `client_secret_post`, callback `/api/auth/callback` | Okta: assignment to group `IT`. Kite gives the admin role from the `groups` claim and by email | Local `admin`, password in `kite-credentials` |
| Hermes dashboard, `hermes.yuandrk.net` | Okta OIDC, Native app, public client with PKCE | Okta: assignment to `Andriuk corp`. Groups are read but not checked | None online: restore `basic_auth` from a config backup over SSH ([hermes-dashboard.md](hermes-dashboard.md#basic_auth-is-gone)) |
| Grafana, `grafana.yuandrk.net` | Local login | `grafana-admin-credentials` | The same login |
| Immich, ActualBudget, n8n, Fleet | Each app's own login | Whatever is set in the app's UI, which is not in git | |
| qBittorrent, `qbit.home.yuandrk.net` | Its own login | Tailnet, and the LAN through the `Host` header | |
| SSH to the nodes | Keys only, port 2222 | | |
| Admin kubeconfig | `/etc/rancher/k3s/k3s.yaml` on k3s-master, copied to `~/.kube/config` | `system:masters`, readable by anything running as `yuandrk`, Hermes included ([hermes-sandbox.md](hermes-sandbox.md#what-this-is-and-is-not)) | |

Kite's OAuth, RBAC and super-user settings come from the `kite-config` ConfigMap through
`KITE_CONFIG_FILE`, so the UI shows them read-only. Change them in git.

## Behind the tunnel, HTTPS has to be asserted

TLS ends at Cloudflare and the tunnel speaks plain HTTP to Traefik. An app therefore believes it
is served over `http://` and builds an `http://` redirect URI, which Okta rejects. Each OIDC app
here pins the scheme its own way, and a new one behind the tunnel needs the same:

| App | Fix |
|-----|-----|
| Headlamp | Traefik middleware `headlamp-https-headers` sets `X-Forwarded-Proto: https`, plus an explicit `HEADLAMP_CONFIG_OIDC_CALLBACK_URL` |
| Kite | `HOST=https://kite.yuandrk.net` pins the callback origin |
| Hermes dashboard | The middleware, plus `FORWARDED_ALLOW_IPS` on the host, plus `dashboard.public_url` ([hermes-dashboard.md](hermes-dashboard.md#why-x-forwarded-proto-needs-two-separate-fixes)) |

## The Headlamp break-glass token has probably expired

The `headlamp-token` item in 1Password holds a token for the `headlamp-admin` ServiceAccount
(cluster-admin). The token the old docs recorded was minted on 2025-08-09 with
`--duration=8760h`. Unless it was rotated since, it stopped working on 2026-08-09. To renew it:

```bash
kubectl create token headlamp-admin -n kube-system --duration=8760h
```

Paste the result into the item's `token` field. The cluster copy updates within 6 hours
([secrets.md](secrets.md#sync-is-slow-on-purpose-every-6-hours)).

## If Okta is down

- **Kite**: the local `admin` login.
- **Headlamp**: the ServiceAccount token, if it is still valid. Otherwise use `kubectl` on k3s-master.
- **Hermes dashboard**: no web login. Use `http://192.168.1.223:9119` on the LAN after restoring
  `basic_auth` over SSH.
- Nothing else depends on Okta.

## Troubleshooting

**Headlamp shows 403 after a successful login.** Open DevTools and check the `Authorization`
header of a failing request. It must carry the OIDC ID token (a JWT starting with `eyJ`), not
the ServiceAccount token. If it does, compare the token's `email` claim with the subject in
`infrastructure/headlamp/base/rbac.yaml`. The API server prefixes it with the issuer and `#`.
