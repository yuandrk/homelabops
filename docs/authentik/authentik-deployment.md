Perfect—thanks for the crisp inputs. I’ll steer this like a production rollout with GitOps-first, and we’ll also include a safe “kubectl test” path.

---

# Plan of record

1. **Preflight + root-cause** (fix the HTTP/HTTPS redirect mismatch).
2. **Confirm target architecture** for your exact domains and modes.
3. **AuthenTik**: create/verify the OIDC Provider+Application (confidential), groups claim.
4. **k3s API server**: (if needed) OIDC flags to validate tokens from Authentik.
5. **Flux GitOps**: update your existing `infrastructure/headlamp/base/` with OIDC, Ingress (Traefik), RBAC, and a SOPS-managed Secret placeholder.
6. **Cloudflare Tunnel**: verify routes and no Access path policies (you said Access = off).
7. **Reconcile + verify**: smoke tests, token claims, RBAC.
8. **Troubleshooting + rollback**.

---

## 0) Preflight & root-cause (redirect URI mismatch)

**Why you’re seeing it**
Headlamp computes the redirect as `https://<headlamp_domain>/oidc-callback`. Its docs are explicit that the callback path is exactly `/oidc-callback`, and that, behind a proxy/LB, the app must see the original scheme via `X-Forwarded-Proto` or it will generate an `http://...` redirect and your IdP (Authentik) rejects it as mismatched. ([headlamp.dev][1])

**Your setup:** Cloudflare terminates TLS (HTTPS), tunnels to Traefik over HTTP. Cloudflare **does** set `X-Forwarded-Proto: https` by default, and Traefik normally forwards it, so Headlamp can still generate a correct `https://…/oidc-callback`. We’ll also set Headlamp’s config via Helm (issuer/client/scopes) so the callback is consistent. ([Cloudflare Docs][2])

**Run these quick preflight checks now**

```bash
# 1) DNS is sane
dig +short headlamp.yuandrk.net @1.1.1.1
dig +short auth.yuandrk.net @1.1.1.1

# 2) Authentik OIDC discovery responds over HTTPS (200 OK + JSON)
curl -fsSL https://auth.yuandrk.net/.well-known/openid-configuration | jq '.issuer,.authorization_endpoint,.token_endpoint,.userinfo_endpoint'

# 3) Headlamp callback endpoint is reachable via Cloudflare Tunnel (expect 200 or 404 HTML, but NOT a scheme-mismatch redirect)
curl -I https://headlamp.yuandrk.net/oidc-callback
```

**What you should see**

* DNS answers; discovery JSON; callback returns an HTTP 200/404 (HTML), not an http→https redirect loop.

**What I need from you**
Paste those three command outputs (especially the headers from step 3).

---

## Target architecture (validated with your inputs)

```
Browser ──HTTPS──> Cloudflare ──HTTP tunnel──> Traefik (IngressClass: traefik)
   |                                  |                          |
 headlamp.yuandrk.net           auth.yuandrk.net                 |
   |                                  |                          |
   v                                  v                          |
Headlamp (in kube-system)  <─OIDC code+PKCE(confidential)─>  Authentik Provider "headlamp"
   |
   |  (ID/access token w/ issuer = https://auth.yuandrk.net/application/o/headlamp/)
   v
kube-apiserver (k3s) validates OIDC (issuer/aud/claims) → RBAC via groups claim
```

Key facts we’ll lock in:

* **Callback URL** must be `https://headlamp.yuandrk.net/oidc-callback`. ([headlamp.dev][1])
* **Headlamp OIDC env/args** are `HEADLAMP_CONFIG_OIDC_CLIENT_ID`, `HEADLAMP_CONFIG_OIDC_CLIENT_SECRET`, `HEADLAMP_CONFIG_OIDC_IDP_ISSUER_URL`, (and optional `HEADLAMP_CONFIG_OIDC_SCOPES`). We’ll set these via the Helm chart’s `config.oidc.*` values. ([headlamp.dev][1])
* Cloudflare adds `X-Forwarded-Proto` so Headlamp keeps `https` in the redirect. ([Cloudflare Docs][2])

---

## 1) Authentik – Provider & Application (confidential client)

Use your existing Provider slug `headlamp` under `auth.yuandrk.net`.

**Settings to confirm**

* **Issuer / discovery**: `https://auth.yuandrk.net/application/o/headlamp/` (discovery is at `/.well-known/openid-configuration`).
* **Redirect URI**: `https://headlamp.yuandrk.net/oidc-callback` (exact). ([headlamp.dev][1])
* **Post-logout redirect**: `https://headlamp.yuandrk.net/`
* **Scopes**: `openid profile email` (Headlamp defaults to these; we can override if needed). ([headlamp.dev][1])
* **Groups claim**: create or reuse a property mapping to emit a list claim (e.g., `ak_groups` or `groups`). Authentik supports custom claim mappings via Property Mappings. ([version-2024-2.goauthentik.io][3])

**What you should see**

* A confidential client with a **client_id** *(you provided: `ajHFJaJnVpaj09shHyQeaTHpi9Llg2wbKi8fxqTF`)* and a **client_secret** (keep secret).
* Discovery JSON returns the expected endpoints.

**What I need from you**

* Confirm the groups claim name you’ll emit (e.g., `ak_groups` or `groups`).
* Confirm that `https://headlamp.yuandrk.net/oidc-callback` is in the Redirect URIs list.

---

## 2) k3s API server OIDC (so tokens from Headlamp are accepted)

If not already set, add to `/etc/rancher/k3s/config.yaml`:

```yaml
# /etc/rancher/k3s/config.yaml
kube-apiserver-arg:
  - oidc-issuer-url=https://auth.yuandrk.net/application/o/headlamp/
  - oidc-client-id=ajHFJaJnVpaj09shHyQeaTHpi9Llg2wbKi8fxqTF
  - oidc-username-claim=preferred_username
  - oidc-groups-claim=<OIDC_GROUPS_CLAIM>  # e.g., ak_groups or groups
```

Then restart: `sudo systemctl restart k3s`. (This allows the API server to validate the audience/issuer it sees from Headlamp users; you can choose your preferred username claim.)

**What you should see**

* `ps aux | grep -i 'k3s server'` shows those args rendered; kubectl keeps working.

**What I need from you**

* Confirm whether these flags are already present (paste sanitized `config.yaml` and k3s args if you have them).

---

## 3) Flux GitOps manifests (idempotent)

You already have:

```
infrastructure/headlamp/base/
  ├─ repository.yaml
  ├─ release.yaml
  ├─ rbac.yaml
  └─ kustomization.yaml
```

Here’s the **first cut** to drop in (update your files accordingly). All sensitive values use placeholders.

### 3.1 HelmRepository (repository.yaml)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: headlamp
  namespace: kube-system
spec:
  interval: 1h
  url: https://kubernetes-sigs.github.io/headlamp/
```

### 3.2 OIDC Secret (SOPS-managed) – new file `secret-oidc.yaml`

> Encrypt this with SOPS (Age) before committing. Namespace must match the HelmRelease namespace.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-oidc
  namespace: kube-system
type: Opaque
stringData:
  clientSecret: "<OIDC_CLIENT_SECRET>"     # 🔐 REPLACE then SOPS-encrypt
```

### 3.3 HelmRelease (release.yaml) – enable OIDC & Traefik Ingress

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: headlamp
  namespace: kube-system
spec:
  interval: 10m
  chart:
    spec:
      chart: headlamp
      version: "0.36.0"
      sourceRef:
        kind: HelmRepository
        name: headlamp
        namespace: kube-system
  values:
    # Run in-cluster mode
    config:
      inCluster: true
      # OIDC config (Headlamp consumes these and exposes /oidc-callback)
      oidc:
        clientID: "ajHFJaJnVpaj09shHyQeaTHpi9Llg2wbKi8fxqTF"
        issuerURL: "https://auth.yuandrk.net/application/o/headlamp/"
        scopes: "openid,profile,email"
        # Pull clientSecret from a Secret, via extraEnv (robust across chart versions)
    extraEnv:
      - name: HEADLAMP_CONFIG_OIDC_CLIENT_SECRET
        valueFrom:
          secretKeyRef:
            name: headlamp-oidc
            key: clientSecret

    # Service/Ingress (Traefik, HTTP at origin; Cloudflare does HTTPS at edge)
    service:
      type: ClusterIP
      port: 80
    ingress:
      enabled: true
      ingressClassName: traefik
      annotations:
        # Ensure Traefik forwards original scheme from Cloudflare (https)
        # (Traefik usually does; this stays as a reminder—no TLS at origin)
        traefik.ingress.kubernetes.io/router.entrypoints: "web"
      hosts:
        - host: headlamp.yuandrk.net
          paths:
            - path: /
              pathType: Prefix
      # Do NOT set TLS here since origin is plain HTTP (Cloudflare terminates TLS)

    # (Optional) security hardening defaults are already good in 0.36.0
```

> Why `extraEnv`? The official chart supports direct `config.oidc.*` and also secret wiring, but versions prior to mid-2025 had edge cases with “external secret” wiring. Injecting the secret as the documented env var is the most portable across chart versions while keeping the rest in values. The env var name matches Headlamp docs. ([headlamp.dev][1])

### 3.4 RBAC (rbac.yaml)

> Bind your IdP groups (from your chosen claim) to Kubernetes roles. Replace placeholders.

```yaml
# Admins
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: Group
    name: "<OIDC_ADMIN_GROUP>"             # e.g., headlamp-admins
    apiGroup: rbac.authorization.k8s.io

---
# Read-only users
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-readonly
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: Group
    name: "<OIDC_READONLY_GROUP>"          # e.g., headlamp-readers
    apiGroup: rbac.authorization.k8s.io
```

> Ensure the **groups claim** emitted by Authentik matches what the apiserver expects (we set `oidc-groups-claim=<OIDC_GROUPS_CLAIM>` in step 2). Authentik can emit groups via a property mapping. ([version-2024-2.goauthentik.io][3])

### 3.5 Kustomization (kustomization.yaml)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kube-system
resources:
  - repository.yaml
  - secret-oidc.yaml     # SOPS-encrypted file
  - release.yaml
  - rbac.yaml
```

**GitOps apply**

```bash
# from your repo root
git add infrastructure/headlamp/base/
git commit -m "headlamp: enable OIDC via Authentik; Traefik ingress; RBAC; SOPS secret placeholder"
git push

# reconcile
flux reconcile source git flux-system --with-source
flux get helmreleases -n kube-system
kubectl -n kube-system get pods -l app.kubernetes.io/name=headlamp -w
```

**What you should see**

* HelmRelease `headlamp` goes `Ready=True`; Pod restarts with OIDC env/args; Ingress propagates; opening the UI shows a **Sign in** button that redirects to Authentik at `https://auth.yuandrk.net/...` and then back to `https://headlamp.yuandrk.net/oidc-callback`.

**What I need from you**

* Confirm you can commit/encrypt the Secret and reconcile.
* If rollout fails, paste `kubectl -n kube-system logs deploy/headlamp --tail=200`.

---

## 4) Cloudflare Tunnel (no Access)

Since Access is **off**, we just need correct tunnel routes:

```yaml
# cloudflared tunnel config snippet (conceptual)
tunnel: <TUNNEL_ID>
ingress:
  - hostname: headlamp.yuandrk.net
    service: http://traefik.kube-system.svc.cluster.local:80
  - hostname: auth.yuandrk.net
    service: http://traefik.kube-system.svc.cluster.local:80
  - service: http_status:404
```

Cloudflare sets `X-Forwarded-Proto` to reflect the client protocol (HTTPS), which Headlamp uses to keep the `https://` scheme for `/oidc-callback`. ([Cloudflare Docs][2])

**What you should see**

* Requests to each hostname route into Traefik; no Access prompts.

**What I need from you**

* If you have a different tunnel topology, paste your current `ingress:` rules (redact IDs/secrets).

---

## 5) Quick “kubectl” test path (optional, no GitOps yet)

If you want to verify OIDC before committing, temporarily inject env vars into the running deployment (don’t paste secrets here; run locally):

```bash
kubectl -n kube-system set env deploy/headlamp \
  HEADLAMP_CONFIG_OIDC_CLIENT_ID=ajHFJaJnVpaj09shHyQeaTHpi9Llg2wbKi8fxqTF \
  HEADLAMP_CONFIG_OIDC_CLIENT_SECRET=<OIDC_CLIENT_SECRET> \
  HEADLAMP_CONFIG_OIDC_IDP_ISSUER_URL=https://auth.yuandrk.net/application/o/headlamp/ \
  HEADLAMP_CONFIG_OIDC_SCOPES="openid,profile,email"
```

Then browse to `https://headlamp.yuandrk.net` and sign in.

**Rollback for this test**
`kubectl -n kube-system rollout undo deploy/headlamp`

---

## 6) Verification & smoke tests

```bash
# Headlamp logs should show OIDC configuration loaded and auth callback hits
kubectl -n kube-system logs deploy/headlamp --tail=200

# Confirm ID token contains your chosen claims (decode in browser devtools or any local jwt tool)
# (Do not paste tokens here; just check fields: iss, aud, email, preferred_username, groups/ak_groups)
```

**What you should see**

* Successful sign-in; user identity shown in Headlamp; access matches your RBAC (admin vs. readonly group).

---

## 7) Troubleshooting quick hits

* **Redirect mismatch (http vs https):** Ensure `X-Forwarded-Proto` reaches Headlamp (Cloudflare sets it; Traefik usually forwards). The Headlamp doc explicitly calls this out for proxies. ([headlamp.dev][1])
* **401/403 after callback:** The Redirect URI must exactly match the Provider config (`/oidc-callback`). Also verify scopes include `openid`. ([headlamp.dev][1])
* **Large tokens / websockets (mostly NGINX):** Headlamp docs show increasing header buffers. You’re on Traefik, so this likely isn’t needed. ([headlamp.dev][1])
* **RBAC denies:** Verify the **groups claim name** in Authentik matches the API server’s `oidc-groups-claim` and your RBAC subject names.

---

## 8) Minimal rollback plan

* **GitOps:** `git revert <commit>` → `git push` → `flux reconcile source git flux-system --with-source`.
* **Temporarily disable OIDC:** remove the four OIDC env/values (and restart), or scale Headlamp down if you need to pause access.

---

# What I still need from you to finish the audit

1. **Preflight outputs** from section 0 (DNS, discovery JSON fields, and headers from the callback check).
2. **Confirm groups claim name** you’ll expose from Authentik (`ak_groups` vs `groups`).
3. (Optional) Your k3s OIDC flags if already present.
4. (Optional) Your cloudflared `ingress:` snippet (redacted).

Once you paste those, I’ll:

* sanity-check your Provider discovery and callback endpoint,
* finalize the RBAC bindings with your real group names, and
* confirm whether we need any Traefik header tweaks (rare with Cloudflare, but I’ll validate).

---

### References (key authoritative bits)

* Headlamp OIDC config & required callback `/oidc-callback`, plus the env var names and proxy note about `X-Forwarded-Proto`. ([headlamp.dev][1])
* Cloudflare sets `X-Forwarded-Proto` to the client protocol (so origin apps can preserve `https`). ([Cloudflare Docs][2])
* Headlamp chart exposes OIDC config via values; Big Bang docs also reflect `config.oidc.*` and `config.baseURL` knobs similarly. ([Big Bang Docs][4])

Take a breath, run the preflights, and we’ll lock this in.

[1]: https://headlamp.dev/docs/latest/installation/in-cluster/oidc/ "Accessing using OpenID Connect | Headlamp"
[2]: https://developers.cloudflare.com/fundamentals/reference/http-headers/?utm_source=chatgpt.com "Cloudflare HTTP headers"
[3]: https://version-2024-2.goauthentik.io/docs/property-mappings/?utm_source=chatgpt.com "Overview"
[4]: https://docs-bigbang.dso.mil/3.8.0/packages/headlamp/values/?utm_source=chatgpt.com "headlamp values.yaml - Big Bang Docs"
