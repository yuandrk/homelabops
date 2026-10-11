# Access

Who can log in where, and the way in when Okta is down.

## Identity provider

Okta, issuer `https://okta.yuandrk.net`. That is the org authorization server behind a custom
domain (`c21d197`), not `/oauth2/default`. Every OIDC client in the homelab uses this issuer.
Okta's own state (apps, groups, assignments) is not exported anywhere, so this page is its only
description.

- **Groups.** `IT` (described as "Homelab admins (Kite)") and `Andriuk corp` ("Main users").
  Both hold only Yurii's own accounts.
- **MFA.** The org's global sign-on policy does not require a second factor. Kite's app policy
  has a `Require MFA` rule. The Hermes dashboard uses Okta's default app policy, and whether that
  demands a second factor is not recorded.

## Login surfaces

| Surface | How you log in | Who gets in | Break-glass |
|---------|----------------|-------------|-------------|
| Kubernetes API through Headlamp, `headlamp.yuandrk.net` | Okta OIDC with PKCE. Headlamp hands the user's ID token to the k3s API server, which validates it (OIDC flags in `/etc/rancher/k3s/config.yaml` on k3s-master) | Okta: **no Headlamp app was found** ([below](#headlamps-okta-app-is-missing)). Kubernetes: `ClusterRoleBinding/headlamp-okta-admin` makes `https://okta.yuandrk.net#me@yuandrk.net` cluster-admin. Anyone else authenticates and then gets 403 | The `headlamp-admin` ServiceAccount token, [expired since 2026-08-09](#the-headlamp-break-glass-token-has-expired), or `kubectl` on k3s-master |
| Kite, `kite.yuandrk.net` | Okta OIDC, Web app, `client_secret_post`, callback `/api/auth/callback` | Okta: assignment to group `IT`. Kite gives the admin role from the `groups` claim and by email | Local `admin`, password in `kite-credentials` |
| Hermes dashboard, `hermes.yuandrk.net` | Okta OIDC, Native app, public client with PKCE | Okta: assignment to `Andriuk corp`. Groups are read but not checked | None online: restore `basic_auth` from a config backup over SSH ([hermes-dashboard.md](hermes-dashboard.md#basic_auth-is-gone)) |
| Grafana, `grafana.yuandrk.net` | Local login | `grafana-admin-credentials` | The same login |
| Immich, ActualBudget, n8n, Fleet | Each app's own login | Whatever is set in the app's UI, which is not in git | |
| qBittorrent, `qbit.home.yuandrk.net` | Its own login | Tailnet, and the LAN through the `Host` header | |
| SSH to the nodes | Keys only. Port 2222, except **22 on k3s-worker3** | `yuandrk`, who can then sudo without a password | |
| Admin kubeconfig | `/etc/rancher/k3s/k3s.yaml` on k3s-master (root-only), copied to `~/.kube/config` | `system:masters`, readable by anything running as `yuandrk`, Hermes included ([hermes-sandbox.md](hermes-sandbox.md#what-this-is-and-is-not)) | |

Kite's OAuth, RBAC and super-user settings come from the `kite-config` ConfigMap through
`KITE_CONFIG_FILE`, so the UI shows them read-only. Change them in git.

k3s's bundled `kubectl` reads `/etc/rancher/k3s/k3s.yaml` whenever `KUBECONFIG` is unset, even
when `~/.kube/config` exists. As `yuandrk` that file is unreadable, so anything that does not
load the shell profile (a non-interactive `ssh k3s-master kubectl …`, a systemd unit, a script)
fails with `permission denied` until it sets `KUBECONFIG=~/.kube/config`.

## Behind the tunnel, HTTPS has to be asserted

TLS ends at Cloudflare and the tunnel speaks plain HTTP to Traefik. An app therefore believes it
is served over `http://` and builds an `http://` redirect URI, which Okta rejects. Each OIDC app
here pins the scheme its own way, and a new one behind the tunnel needs the same:

| App | Fix |
|-----|-----|
| Headlamp | Traefik middleware `headlamp-https-headers` sets `X-Forwarded-Proto: https`, plus an explicit `HEADLAMP_CONFIG_OIDC_CALLBACK_URL` |
| Kite | `HOST=https://kite.yuandrk.net` pins the callback origin |
| Hermes dashboard | The middleware, plus `FORWARDED_ALLOW_IPS` on the host, plus `dashboard.public_url` ([hermes-dashboard.md](hermes-dashboard.md#why-x-forwarded-proto-needs-two-separate-fixes)) |

## Headlamp's Okta app is missing

The inventory of 2026-10-11 listed the Okta org's apps: Kite, the Hermes dashboard, a bookmark
tile, an app for an Okta MCP client, and Okta's own. None is for Headlamp or the k3s API, and
none has the client ID that the API server's `oidc-client-id` names. Either the listing missed
the app, or Headlamp's Okta login no longer works. With the break-glass token expired too,
Headlamp may have no working login at all.

Try logging in at `headlamp.yuandrk.net`. If it fails, recreate the app:

- Okta: a Web app with authorization code and PKCE, sign-in redirect
  `https://headlamp.yuandrk.net/oidc-callback`, assigned to `IT`.
- 1Password: its client ID and secret into the item `headlamp-oidc-okta` (fields `clientID`,
  `clientSecret`; `issuerURL` and `scopes` stay).
- k3s-master: the same client ID as `oidc-client-id` in `/etc/rancher/k3s/config.yaml`, then
  restart k3s. The API server rejects any ID token whose audience is a different client.

## The Headlamp break-glass token has expired

The `headlamp-token` item in 1Password holds a token for the `headlamp-admin` ServiceAccount
(cluster-admin). It was minted on 2025-08-09 with `--duration=8760h`, and its `exp` claim is
2026-08-09. To renew it:

```bash
kubectl create token headlamp-admin -n kube-system --duration=8760h
```

Paste the result into the item's `token` field. The cluster copy updates within 6 hours
([secrets.md](secrets.md#sync-is-slow-on-purpose-every-6-hours)). A token minted this way
expires again in a year.

## If Okta is down

- **Kite**: the local `admin` login.
- **Headlamp**: the ServiceAccount token, once it is renewed. Until then, `kubectl` on k3s-master.
- **Hermes dashboard**: no web login. Use `http://192.168.1.223:9119` on the LAN after restoring
  `basic_auth` over SSH.
- Nothing else depends on Okta.

## Troubleshooting

**Headlamp shows 403 after a successful login.** Open DevTools and check the `Authorization`
header of a failing request. It must carry the OIDC ID token (a JWT starting with `eyJ`), not
the ServiceAccount token. If it does, compare the token's `preferred_username` claim with the
subject in `infrastructure/headlamp/base/rbac.yaml`. The API server takes the username from that
claim (`oidc-username-claim=preferred_username`) and prefixes it with the issuer and `#`.
