# Hermes dashboard — `hermes.yuandrk.net`

The Hermes agent's web dashboard, published through the Cloudflare Tunnel and authenticated
against Okta.

## What is unusual about it

Every other service in this repo is a pod. This one is a **host process on k3s-master**: the user
unit `hermes-dashboard.service`, running `hermes dashboard --no-open --host 0.0.0.0 --port 9119`
out of `~/.hermes`. It stays outside k3s on purpose, as the agent's control channel
([decisions.md](decisions.md#standing-decisions)). Publishing it through Traefik trades that
independence for the public hostname: **if the cluster is down, `hermes.yuandrk.net` is down**.
The process still answers on `http://192.168.1.223:9119` (LAN) and `http://100.96.117.64:9119`
(tailnet), but the OIDC login returns to the dead public name, so logging in that way needs
`basic_auth` restored first ([below](#basic_auth-is-gone)).

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

The Service has no selector and its EndpointSlice is written by hand: there is no pod to select.
It is the only Ingress in the repo with a backend outside the cluster, and two things about it
bite:

- The Service port name (`http`) and the EndpointSlice port name must be identical. They are
  matched by name, and a mismatch gives an endpoint-less Service and a bare 502.
- Nothing health-checks a hand-written slice. `conditions.ready: true` is an assertion, so
  Traefik keeps routing there even when Hermes is stopped.

## Why `X-Forwarded-Proto` needs two separate fixes

TLS ends at Cloudflare and the tunnel speaks plain HTTP to Traefik, so Hermes believes it serves
`http://`. That breaks the session cookie's `Secure` flag and the OAuth `redirect_uri`, which
Okta rejects. The fix has two halves, and each is useless alone:

1. **Traefik sends the header.** `infrastructure/hermes-dashboard/base/middleware.yaml` sets
   `X-Forwarded-Proto: https`, referenced from the Ingress as
   `hermes-dashboard-hermes-https-headers@kubernetescrd`.
2. **uvicorn believes it.** It honours `X-Forwarded-*` only from peers in `FORWARDED_ALLOW_IPS`,
   which defaults to `127.0.0.1`, and Hermes offers no other setting for it. A drop-in on the
   host sets it, scoped to the pod CIDR so that a LAN client hitting `:9119` directly cannot
   forge the scheme:

   ```ini
   # ~/.config/systemd/user/hermes-dashboard.service.d/proxy.conf
   [Service]
   Environment=FORWARDED_ALLOW_IPS=10.42.0.0/16
   ```

`dashboard.public_url: https://hermes.yuandrk.net` in `config.yaml` pins the callback URL as
well, but it does not set the cookie's `Secure` flag, so it cannot replace step 2.

## Okta

| | |
|---|---|
| Issuer | `https://okta.yuandrk.net`, the same as Kite |
| App | `Hermes Dashboard`, OIDC **Native** app, **public client** (`token_endpoint_auth_method: none`) |
| Redirect URI | `https://hermes.yuandrk.net/auth/callback`. It **must** end in `/auth/callback`: Hermes validates it and fails fast otherwise |
| Authorization | Okta **app assignment** to `Andriuk corp`, and nothing else |

Hermes uses its bundled `self_hosted` provider: authorization code with PKCE, and the ID token
verified against the discovered `jwks_uri`. Its settings are under `dashboard.oauth.self_hosted`
in `~/.hermes/config.yaml`. A forward-auth proxy would not help, because Hermes has no
trusted-header mode.

It has to be a **public client**, and `config.yaml` deliberately carries no `client_secret`.
Given a secret, Hermes authenticates with HTTP Basic while still sending `client_id` in the
body, and Okta rejects the pair with `401 invalid_request` ("Cannot supply multiple client
credentials"). Okta allows `token_endpoint_auth_method: none` only on Native apps and cannot
change an app's type, hence the Native app. Security rests on PKCE `S256`, exact redirect-URI
matching and the assignment
([decision](decisions.md#2026-08-22--hermes-dashboard-on-okta-as-a-public-client-without-a-fallback)).

Hermes reads `groups` for display only. Removing someone from `Andriuk corp`, the general users
group rather than `IT`, is what revokes access, and anyone added to it gains the agent's control
channel.

## `basic_auth` is gone

The shared username and password login was removed once SSO worked, because the dashboard is
reachable from the internet. `/api/auth/providers` lists `self-hosted` and nothing else, and
`POST /auth/password-login` answers `404 Unknown provider`.

**That removed the fallback.** If Okta is unreachable there is no other way into the web UI:
restore `dashboard.basic_auth` from a `config.yaml.bak-preremove-*` backup over SSH and restart
the unit. `config.yaml` and the drop-in exist only on k3s-master
([off-git.md](off-git.md#k3s-master)).

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

To check Okta's client authentication without a browser, POST a deliberately invalid code to the
token endpoint with only `client_id` and `code_verifier`: `invalid_grant` means the client
authentication passed, `invalid_request` or `invalid_client` means it did not.

**Rollback:** restore a `config.yaml.bak-*` over `config.yaml` and
`systemctl --user restart hermes-dashboard`, choosing a backup that still contains `basic_auth`.
Removing the `hermes` entry from `local.tunnel_services` withdraws the public name, leaving
`192.168.1.223:9119` on the LAN.
