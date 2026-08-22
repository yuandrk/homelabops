# Hermes dashboard — `hermes.yuandrk.net`

The Hermes agent's web dashboard, published through the Cloudflare Tunnel and authenticated
against Okta.

## What is unusual about it

Every other service in this repo is a pod. This one is not: the dashboard is a **host process on
k3s-master**, the user systemd unit `hermes-dashboard.service`, running
`hermes dashboard --no-open --host 0.0.0.0 --port 9119` out of `/home/yuandrk/.hermes`. It lives
outside k3s on purpose — it is the agent's control channel, so it must keep working when the
cluster does not (see [hermes-sandbox.md](hermes-sandbox.md) and the `hermes-stays-outside-k3s`
note).

Publishing it through Traefik therefore trades that independence away for the public hostname:
**if the cluster is down, `hermes.yuandrk.net` is down.** The out-of-band path is still
`http://192.168.1.223:9119` on the LAN, or `http://100.96.117.64:9119` from the tailnet.

## The routing chain

```
browser → Cloudflare edge (TLS)
        → cloudflared (networking ns, 2 replicas)
        → traefik.kube-system.svc:80
        → Ingress hermes.yuandrk.net           infrastructure/hermes-dashboard/base/ingress.yaml
        → Service hermes-dashboard (no selector)  …/service.yaml
        → EndpointSlice → 192.168.1.223:9119      …/service.yaml
        → uvicorn on k3s-master
```

The Service has **no selector** and its EndpointSlice is written by hand — there is no pod to
select. This is the only Ingress→off-cluster backend in the repo. Two things about it bite:

- The Service port name (`http`) and the EndpointSlice port name must be identical. They are
  matched by name, not position; a mismatch yields an endpoint-less Service and a bare 502.
- Nothing health-checks a hand-written slice. `conditions.ready: true` is an assertion, so
  Traefik keeps routing there even when Hermes is stopped.

The node address `192.168.1.223` is hardcoded because nothing in the cluster knows about a
process that is not in the cluster.

## Why `X-Forwarded-Proto` needs two separate fixes

TLS terminates at Cloudflare and the tunnel speaks plain HTTP to Traefik, so without help the
backend believes it is serving `http://`. That breaks two things at once in Hermes:

- `dashboard_auth/cookies.py` (`detect_https`) sets the session cookie's `Secure` flag from
  `request.url.scheme`.
- The OIDC provider reconstructs the OAuth `redirect_uri` from the request, and Okta rejects a
  non-HTTPS `redirect_uri`.

Fixing it takes **both** halves, and each is useless alone:

1. **Traefik must send the header.** `infrastructure/hermes-dashboard/base/middleware.yaml` sets
   `X-Forwarded-Proto: https`, referenced from the Ingress as
   `hermes-dashboard-hermes-https-headers@kubernetescrd`. Same trick as
   `infrastructure/headlamp/base/middleware.yaml`.
2. **uvicorn must believe it.** uvicorn only honours `X-Forwarded-*` from peers in
   `FORWARDED_ALLOW_IPS`, which defaults to `127.0.0.1` — a Traefik pod is not that, so the
   header is silently dropped. `hermes_cli/web_server.py` builds its `uvicorn.Config` without
   `forwarded_allow_ips`, so the env var is the only lever. It is set in a drop-in **on the
   host**:

   ```ini
   # ~/.config/systemd/user/hermes-dashboard.service.d/proxy.conf
   [Service]
   Environment=FORWARDED_ALLOW_IPS=10.42.0.0/16
   ```

   Scoped to the k3s pod CIDR rather than `*`, so a LAN client hitting `:9119` directly cannot
   forge the scheme.

As a belt-and-braces third measure, `dashboard.public_url` is pinned to
`https://hermes.yuandrk.net` in `config.yaml`. It takes priority over header reconstruction for
the callback URL — but it does **not** affect the cookie `Secure` flag, which is why it does not
replace step 2.

## Okta

| | |
|---|---|
| Issuer | `https://okta.yuandrk.net` (same as Headlamp and the k3s apiserver) |
| App | `Hermes Dashboard`, OIDC Web app, `client_id` `0oa16pzv08uDQV7Fy698` |
| Redirect URI | `https://hermes.yuandrk.net/auth/callback` — **must** end in `/auth/callback`, the provider validates this and fails fast otherwise |
| Authorization | Okta **app assignment** only — the app is assigned to `homelab-admins` |

Hermes uses its own bundled `self_hosted` provider
(`plugins/dashboard_auth/self_hosted/`), a confidential client doing authorization-code + PKCE
and verifying the ID token against the discovered `jwks_uri`. No oauth2-proxy is involved and
none would help: Hermes has no trusted-header auth mode, so a forward-auth proxy could only
stack in front of its own `/login`.

It reads `groups` from the ID token but only for display — **it does not authorize on them.**
Access control is entirely "is this user assigned to the app in Okta". Removing someone from
`homelab-admins` is what revokes access.

## What is not in git

This is the real gap. Two files live only on k3s-master:

- `/home/yuandrk/.hermes/config.yaml` (mode 0600) — holds `dashboard.oauth.self_hosted.*`
  including the Okta **client secret**, plus the `basic_auth` hash and session-signing key
- `/home/yuandrk/.config/systemd/user/hermes-dashboard.service.d/proxy.conf`

Timestamped backups of the config sit next to it as `config.yaml.bak-*`. The Okta client
credentials belong in the 1Password `homelab` vault as well; they are **not** synced into k8s,
because Hermes does not run in k8s.

## Operations

```bash
# state and logs (user scope — note the --user)
ssh k3s-master "systemctl --user status hermes-dashboard"
ssh k3s-master "journalctl --user -u hermes-dashboard -n 50 --no-pager"

# which auth providers are live
curl -s http://192.168.1.223:9119/api/auth/providers

# public path
curl -s -o /dev/null -w '%{http_code}\n' https://hermes.yuandrk.net/    # 302 → /login
curl -s https://hermes.yuandrk.net/api/auth/me                          # 401 JSON when logged out

# does Traefik still reach the host? (empty endpoints ⇒ 502)
kubectl get endpointslice -n hermes-dashboard
kubectl -n kube-system exec deploy/traefik -- wget -qS -O /dev/null http://192.168.1.223:9119/
```

**Rollback:** comment out `dashboard.oauth.self_hosted` in `config.yaml` and
`systemctl --user restart hermes-dashboard` — the `basic` username/password provider is still
configured and keeps working. Removing the `hermes` entry from `local.tunnel_services` in
`terraform/live/homelab/cloudflare/main.tf` withdraws the public name entirely.
