# Access

Who can log in where, and the way in when Okta is down.

## Identity provider

Okta, issuer `https://okta.yuandrk.net`: the org authorization server behind a custom domain
(`c21d197`), not `/oauth2/default`. Every OIDC client in the homelab uses this issuer. Okta's own
state (apps, groups, assignments) is not exported anywhere, so this page is its only description.

- **Groups.** `IT` (described as "Homelab admins (Kite)") and `Andriuk corp` ("Main users").
  Both hold only Yurii's own accounts.
- **MFA.** The org's global sign-on policy does not require a second factor. Kite's app policy
  has a `Require MFA` rule. The Hermes dashboard uses Okta's default app policy, and whether that
  demands a second factor is not recorded.

## Login surfaces

| Surface | How you log in | Who gets in | Break-glass |
|---------|----------------|-------------|-------------|
| Kite, `kite.yuandrk.net` | Okta OIDC, Web app, `client_secret_post`, callback `/api/auth/callback` | Okta: assignment to group `IT`. Kite gives the admin role from the `groups` claim and by email. Its OAuth, RBAC and super-user settings come from the `kite-config` ConfigMap, so the UI shows them read-only: change them in git | Local `admin`, password in `kite-credentials` |
| Hermes dashboard, `hermes.yuandrk.net` | Okta OIDC, Native app, public client with PKCE | Okta: assignment to `Andriuk corp`. Groups are read but not checked | None online: restore `basic_auth` over SSH ([hermes-dashboard.md](hermes-dashboard.md#basic_auth-is-gone)) |
| Grafana, `grafana.yuandrk.net` | Local login | `grafana-admin-credentials` | The same login |
| Immich, ActualBudget, n8n, Fleet | Each app's own login | Whatever is set in the app's UI, which is not in git | |
| SSH to the nodes | Keys only, on the [ports listed here](network-architecture.md#listening-ports) | `yuandrk`, who can then sudo without a password | |
| Admin kubeconfig | `/etc/rancher/k3s/k3s.yaml` on k3s-master (root-only), copied to `~/.kube/config` | `system:masters`, readable by anything running as `yuandrk`, Hermes included ([hermes-sandbox.md](hermes-sandbox.md#what-this-is-and-is-not)) | |

k3s's bundled `kubectl` reads `/etc/rancher/k3s/k3s.yaml` whenever `KUBECONFIG` is unset, even
when `~/.kube/config` exists. As `yuandrk` that file is unreadable, so anything that does not
load the shell profile (a non-interactive `ssh k3s-master kubectl …`, a systemd unit, a script)
fails with `permission denied` until it sets `KUBECONFIG=~/.kube/config`.

The k3s API server still carries Okta OIDC flags from Headlamp's time, in
`/etc/rancher/k3s/config.yaml`. They grant nothing: nothing sends it Okta tokens any more, and
no RBAC binding names an Okta user. They go at the next k3s restart ([TODO](TODO.md#cleanup)).

## Behind the tunnel, HTTPS has to be asserted

TLS ends at Cloudflare and the tunnel speaks plain HTTP to Traefik. An app therefore believes it
is served over `http://` and builds an `http://` redirect URI, which Okta rejects. Each OIDC app
here pins the scheme its own way, and a new one behind the tunnel needs the same:

| App | Fix |
|-----|-----|
| Kite | `HOST=https://kite.yuandrk.net` pins the callback origin |
| Hermes dashboard | The middleware, plus `FORWARDED_ALLOW_IPS` on the host, plus `dashboard.public_url` ([hermes-dashboard.md](hermes-dashboard.md#why-x-forwarded-proto-needs-two-separate-fixes)) |

## Break-glass

When Okta is down:

- **Kite**: the local `admin` login.
- **Hermes dashboard**: no web login. Restore `basic_auth` over SSH, then use
  `http://192.168.1.223:9119` on the LAN ([hermes-dashboard.md](hermes-dashboard.md#basic_auth-is-gone)).
- Nothing else depends on Okta.
