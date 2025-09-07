We'll structure this into clear GitOps-compatible phases to get `auth.yuandrk.net` operational. Let's begin with Phase 1.

Research completed in 6m · 8 sources · 39 searches

Deploy Authentik on K3s Using FluxCD GitOps

# Deploying Authentik on K3s with FluxCD (GitOps) and External PostgreSQL

## Phase 1: Preparation and Prerequisites ✅ COMPLETED

1.  **✅ PostgreSQL Setup:** PostgreSQL is running on k3s-worker1:5432 via Docker. Successfully created and configured:
    
    ```sql
    -- Completed on 2025-09-06
    CREATE USER authentik WITH PASSWORD '<strong-password>';
    CREATE DATABASE authentik; -- (already existed)
    GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;
    GRANT ALL ON SCHEMA public TO authentik;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO authentik;
    \c authentik;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "citext";
    ```
    
    **Verification completed:**
    - ✅ authentik user can connect: `postgresql://authentik:<password>@k3s-worker1:5432/authentik`
    - ✅ Database operations (CREATE/INSERT/SELECT/DROP) working
    - ✅ Required extensions installed (uuid-ossp, citext)  
    - ✅ Network connectivity verified from cluster pods
    - ✅ PostgreSQL 15.13 running on aarch64
    
2.  **Check GitOps Repository Structure:** Confirm your Git repository is structured for Flux. You should have a base directory for apps (e.g. `apps/authentik/base/`) and an overlay for your production cluster (e.g. `clusters/prod/`). Flux should be configured to sync the `clusters/prod` path for deployments. Ensure FluxCD and SOPS integration are set up (Flux needs access to your SOPS decryption keys)[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=,authentik).
    
3.  **DNS and Ingress:** Verify that the DNS record for **auth.yuandrk.net** is in place and the Cloudflare Tunnel is routing traffic to your Traefik ingress controller. You can test by hitting a simple existing service through Traefik if available. Ensure Traefik is configured with an IngressClass (e.g. `traefik`) and is ready to serve the domain.
    

**Verification Checklist:**

-    **PostgreSQL**: *Auth* database and user exist; you can connect from the cluster to the DB using the `authentik` credentials.
    
-    **Secrets**: SOPS is configured in Flux and you have generated strong values for the PostgreSQL password, Authentik secret key, and initial admin password.
    
-    **Infrastructure**: FluxCD is running on the cluster and pointing to your Git repo; Traefik ingress is functional; Cloudflare tunnel for **auth.yuandrk.net** is active.
    

## Phase 2: Creating Authentik Base Manifests (GitOps Base)

In this phase, we will define the base Kubernetes manifests for Authentik (to be placed under `apps/authentik/base` in your Git repo). This includes a Namespace, HelmRepository for the Authentik chart, and a HelmRelease that describes how Authentik is deployed.

1.  **Namespace and Helm Repository:** Create a file `apps/authentik/base/namespace.yaml` to define the namespace, and `apps/authentik/base/helmrepo.yaml` for the Helm repository source:
    
    ```yaml
    # namespace.yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: authentik
      labels:
        app: authentik
    ---
    # helmrepo.yaml
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: HelmRepository
    metadata:
      name: authentik
      namespace: flux-system  # or your Flux source namespace
    spec:
      interval: 5m
      url: https://charts.goauthentik.io
    ```
    
    This creates a new Kubernetes namespace `authentik` for the deployment[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=,apiVersion%3A%20source.toolkit.fluxcd.io%2Fv1) and instructs Flux to pull the official Authentik Helm chart from the provided Helm repository[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=apiVersion%3A%20source,io). Adjust the `namespace:` for HelmRepository if your Flux is configured to use a different namespace (often `flux-system` or similar).
    
2.  **HelmRelease Definition:** Create `apps/authentik/base/helmrelease.yaml` with the HelmRelease that uses the official chart. This will reference our external PostgreSQL and configure Authentik’s settings via Helm values. For example:
    
    ```yaml
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: authentik
      namespace: authentik
    spec:
      interval: 5m0s
      timeout: 5m0s
      chart:
        spec:
          chart: authentik
          version: "*"
          sourceRef:
            kind: HelmRepository
            name: authentik    # matches the HelmRepository above
            namespace: flux-system
      # Inject sensitive values from a Secret (defined later) using Flux's valuesFrom:
      valuesFrom:
        - kind: Secret
          name: authentik-credentials
          valuesKey: secret-key
          targetPath: authentik.secret_key
        - kind: Secret
          name: authentik-credentials
          valuesKey: postgresql-password
          targetPath: authentik.postgresql.password
        - kind: Secret
          name: authentik-credentials
          valuesKey: admin-password
          targetPath: authentik.bootstrap_password
      values:
        authentik:
          # Basic Authentik configuration
          error_reporting:
            enabled: false  # disable anonymous usage reporting (optional):contentReference[oaicite:5]{index=5}
          postgresql:
            host: "<POSTGRES_HOST_OR_IP>"       # e.g. the IP or hostname of k3s-worker1 running Postgres
            port: 5432                          # default PostgreSQL port:contentReference[oaicite:6]{index=6}
            name: authentik                     # database name (we created this)
            user: authentik                     # database user
          # password is injected via valuesFrom -> authentik.postgresql.password
          secret_key: ""      # will be injected via valuesFrom -> authentik.secret_key
          bootstrap_password: ""  # will be injected via valuesFrom -> authentik.bootstrap_password (for akadmin)
          # (Optional) bootstrap_token and bootstrap_email can be set if you want to pre-create an API token or set admin email:contentReference[oaicite:7]{index=7}:contentReference[oaicite:8]{index=8}
          # bootstrap_token: "<some-token>"    # optional, set if you want an API token on first startup
          # bootstrap_email: "admin@yourdomain.com"  # optional, set admin email for akadmin user
        postgresql:
          enabled: false      # Disable the default PostgreSQL sub-chart – we are using an external DB
        redis:
          enabled: true       # Enable the built-in Redis sub-chart for caching (deploys a Redis instance):contentReference[oaicite:9]{index=9}
        server:
          ingress:
            enabled: true
            ingressClassName: traefik          # Traefik ingress class (adjust if your class name differs)
            annotations:
              # Example: If using cert-manager for TLS, specify the ClusterIssuer
              cert-manager.io/cluster-issuer: "letsencrypt-prod"
              # If Cloudflare Tunnel terminates TLS externally, you might not need cert-manager. In that case, you can use a Cloudflare Origin Cert or set Traefik to no-TLS.
            hosts:
              - auth.yuandrk.net
            tls:
              - hosts:
                  - auth.yuandrk.net
                secretName: authentik-tls      # Secret for TLS certificate (if using cert-manager or pre-provisioned cert)
    ```
    
    **Explanation:** This HelmRelease instructs Flux to install the Authentik chart from our Helm repo. We set key configuration via `spec.values`:
    
    -   **Database Config:** We provide Authentik with the external PostgreSQL connection info (host, port, database name, user)[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=postgresql%3A%20host%3A%20postgresql,name%3A%20authentik%20user%3A%20authentik). These correspond to environment variables `AUTHENTIK_POSTGRESQL__HOST`, `__PORT`, `__NAME`, `__USER` in Authentik[docs.goauthentik.io](https://docs.goauthentik.io/install-config/configuration/#:~:text=,the%20default%20Docker%20Compose%20setup). The password is not put here in plaintext – it will be supplied from a Secret.
        
    -   **Secret Key & Admin Password:** `authentik.secret_key` and `authentik.bootstrap_password` are left empty in values and will be filled from a Kubernetes Secret via `valuesFrom`. This keeps secrets out of Git and inside SOPS-encrypted files[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=valuesFrom%3A%20,password%20targetPath%3A%20authentik.postgresql.password)[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=apiVersion%3A%20v1%20kind%3A%20Secret%20metadata%3A,Database%20password%20%28redacted). The **secret key** is a random string for cryptographic signing in Authentik, and **bootstrap\_password** sets the initial password for the default admin user `akadmin` (read only on first startup)[docs.goauthentik.io](https://docs.goauthentik.io/install-config/automated-install/#:~:text=).
        
    -   **Built-in Redis:** We enable `redis.enabled: true` so the Helm chart deploys a Redis instance (using Bitnami Redis) for caching/background tasks[surajremanan.com](https://surajremanan.com/posts/authentik-with-kubernetes-forward-auth/#:~:text=Authentik%20with%20Kubernetes%3A%20Forward%20Authentication,io%20helm%20repo). This avoids needing an external Redis. The chart will connect Authentik to this Redis automatically. (If you already have a Redis service, you could set `redis.enabled: false` and provide `authentik.redis.host` and password instead.)
        
    -   **Ingress:** The `server.ingress` block enables an Ingress for the Authentik UI. We set the host to **auth.yuandrk.net** and use the Traefik ingress class. TLS is configured with a secret name `authentik-tls` and an annotation for cert-manager’s ClusterIssuer in this example[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=ingress%3A%20enabled%3A%20true%20ingressClassName%3A%20public,authentik.apps.timvw.be). Adjust these based on your environment:
        
        -   If you use cert-manager, ensure an Issuer/ClusterIssuer is configured for Cloudflare/Let’s Encrypt (or use Cloudflare DNS challenge).
            
        -   If Cloudflare Tunnel terminates SSL, you can either use a Cloudflare Origin Certificate in Traefik or use “Full” SSL (in which case cert-manager is still used to get a cert). The above assumes you’re using Let’s Encrypt via cert-manager. *(Make sure the Traefik ingress controller is configured to handle the `auth.yuandrk.net` host and that the Cloudflare Tunnel is passing HTTPS traffic to Traefik.)*
            
3.  **Kustomization Base:** Create `apps/authentik/base/kustomization.yaml` to bundle these resources:
    
    ```yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - namespace.yaml
      - helmrepo.yaml
      - helmrelease.yaml
    ```
    
    This allows Flux (or `kubectl kustomize`) to apply all base manifests together.
    
4.  **Review Changes:** At this point, your base manifests for Authentik are ready in Git. Review that the HelmRelease correctly references the chart and that no sensitive values are hard-coded. The database host/user/name should be correct for your setup. The placeholders (`<POSTGRES_HOST_OR_IP>`, etc.) should be replaced with real values (except passwords/keys which we will handle via Secret).
    

**Verification Checklist:**

-    **Namespace & HelmRepo:** `apps/authentik/base/namespace.yaml` and `helmrepo.yaml` are created and contain the correct namespace name and chart repository URL.
    
-    **HelmRelease:** `apps/authentik/base/helmrelease.yaml` is created with the correct chart reference and values (external DB info, `redis.enabled: true`, ingress host, etc.). No plaintext secrets are present.
    
-    **Flux Kustomization:** `apps/authentik/base/kustomization.yaml` includes all the above resources. The base will create the Authentik namespace and instruct Flux how to get the Helm chart.
    
-    **Chart Reference:** Flux will be able to pull the Authentik chart (e.g., try `helm search repo authentik` or check ArtifactHub to verify the chart name and version). Ensure internet access from cluster for Flux to fetch the chart.
    

## Phase 3: Configuring Secrets with SOPS (Production Overlay)

With the base in place, now create the production-specific overlay, including the SOPS-encrypted secrets. This overlay will provide environment-specific configuration, mainly the secret values that we kept out of the base.

1.  **Create Authentik Secret (SOPS Encrypted):** In your repository, go to `clusters/prod/secrets/` (or wherever you keep environment secrets) and create a file (e.g. `authentik-credentials.yaml`). This file will define a Kubernetes Secret for Authentik’s sensitive values. **Do NOT commit it in plaintext.** Instead, populate it and then encrypt with SOPS. For example, before encryption the YAML might look like:
    
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: authentik-credentials
      namespace: authentik
    type: Opaque
    stringData:
      postgresql-password: "<POSTGRES_AUTHENTIK_USER_PASSWORD>"
      secret-key: "<GENERATED_AUTHENTIK_SECRET_KEY>"
      admin-password: "<INITIAL_AKADMIN_PASSWORD>"
    ```
    
    -   Use the actual password for the `authentik` PostgreSQL user (`postgresql-password` key). This should match the user/password created in Phase 1.
        
    -   Generate a **secret-key** value for Authentik’s cryptographic signing. This should be a long random string (e.g. 32+ characters of entropy). You can generate one with a command like `openssl rand -base64 32`. Keep this secret – it's like a “pepper” for tokens/sessions.
        
    -   Set the **admin-password** to a strong password for the default `akadmin` account. This will be applied on first startup[docs.goauthentik.io](https://docs.goauthentik.io/install-config/automated-install/#:~:text=), allowing you to log into Authentik without the interactive setup. *(You can also include `bootstrap_token` in this Secret if you want an API token created on first run, but it’s optional.)*
        
    
    Once the file is prepared, encrypt it with SOPS (using your chosen KMS, GPG, or age key). For example: `sops -e -i clusters/prod/secrets/authentik-credentials.yaml`. The resulting file in Git should be SOPS-encrypted (unreadable plaintext). **Double-check** that no secret values are visible in Git. Flux will decrypt this at deploy time, provided it’s configured with the correct decryption keys[medium.com](https://medium.com/@platform.engineers/fluxcd-and-microservices-managing-multi-service-deployments-with-gitops-02be50635739#:~:text=,key%3E%20secrets).
    
2.  **Create the Production Overlay Kustomization:** Now create a Kustomization for the production environment that pulls in the Authentik base and the secret. For example, `clusters/prod/authentik/kustomization.yaml`:
    
    ```yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - ../../../apps/authentik/base    # Path to the base manifests
      - ../secrets/authentik-credentials.yaml  # SOPS-encrypted secret for Authentik
    ```
    
    This overlay references the base (created in Phase 2) and the secret file. When Flux applies this, it will first decrypt `authentik-credentials.yaml` and create the Secret, then apply the HelmRelease. The HelmRelease will pull the secret values via `valuesFrom` and deploy the Authentik chart with those secrets injected[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=valuesFrom%3A%20,password%20targetPath%3A%20authentik.postgresql.password)[timvw.be](https://timvw.be/2025/03/17/setting-up-authentik-with-kubernetes-and-fluxcd/#:~:text=A%20key%20part%20of%20this,This%20approach).
    
3.  **Include Overlay in Flux:** Depending on how your Flux is configured, you may need to add this new overlay to your Flux Kustomization. For example, if `clusters/prod/kustomization.yaml` exists (a higher-level kustomization listing all app overlays), include `./authentik/` in its resources. If instead you have Flux set up with one Kustomization per app, you might create a `Kustomization` CR for Authentik. For instance:
    
    ```yaml
    # Example Flux Kustomization (if using one-per-app approach)
    apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
    kind: Kustomization
    metadata:
      name: authentik-prod
      namespace: flux-system
    spec:
      path: "./clusters/prod/authentik"
      prune: true
      interval: 10m
      dependsOn: []  # if other dependencies, list them (e.g., maybe depends on flux syncing secrets)
      # Decryption is usually enabled globally; ensure .spec.decryption is set if needed.
    ```
    
    Adjust according to your GitOps setup. The goal is to ensure Flux knows to apply the `clusters/prod/authentik` kustomization. If you used a single `clusters/prod/kustomization.yaml` that already includes `apps/authentik/base`, you might instead just add the secret there. The structure can vary, but **make sure the Authentik secret and HelmRelease are included in the Flux sync.**
    

**Verification Checklist:**

-    **Secret Encrypted:** The `authentik-credentials.yaml` (or similarly named file) is encrypted with SOPS and contains the keys (`postgresql-password`, `secret-key`, `admin-password`). No plaintext secrets in the repo.
    
-    **Overlay Config:** The `clusters/prod/authentik/kustomization.yaml` (or your equivalent overlay) exists and references both the base and the secret. Paths are correct.
    
-    **Flux Aware of Overlay:** Verify that Flux will apply the Authentik manifests. For example, check Flux’s Kustomization definitions or `clusters/prod/kustomization.yaml` to confirm the Authentik overlay is included. This ensures that when you push the changes, Flux knows to deploy Authentik.
    

## Phase 4: Deployment via FluxCD

With both base and overlay ready in Git, you can now deploy Authentik by pushing these changes and letting Flux apply them through GitOps.

1.  **Commit and Merge:** Commit all the new files (`apps/authentik/base/*`, `clusters/prod/authentik/*`, and secret) to a new branch. Open a Pull Request for review (as per your GitOps practice) and merge it into the main branch that Flux watches. Ensure your PR does **not** reveal any secret content (the secret file should appear encrypted).
    
2.  **Flux Synchronization:** Once merged, Flux will notice the changes (typically within its sync interval, e.g. 1 minute). You can monitor Flux via its logs or CLI:
    
    -   Run `flux reconcile source git <your-git-source-name> --namespace=flux-system` to prompt Flux to fetch the latest Git commit.
        
    -   Then run `flux reconcile kustomization prod --namespace=flux-system` (or the name of your Kustomization) to prompt an immediate apply. This is optional; Flux will do it eventually, but it speeds up deployment.
        
3.  **Check HelmRelease and Pods:** Use kubectl to verify that the HelmRelease and related resources are created:
    
    -   `kubectl get helmrelease -n authentik` – you should see the Authentik HelmRelease. Wait until its `Ready` status becomes `True` (Flux will install the chart).
        
    -   `kubectl get pods -n authentik` – you should see pods for Authentik. The chart typically deploys at least: an **authentik-server** (the web server), an **authentik-worker** (for background tasks), and possibly a **redis** pod (since we enabled `redis.enabled`). All pods should eventually be in Running state. For example:
        
        ```bash
        $ kubectl get pods -n authentik
        NAME                                   READY   STATUS    RESTARTS   AGE
        authentik-server-5c8df7b7b9-mxkfh      1/1     Running   0          1m
        authentik-worker-7d9f4c9f6c-abcde      1/1     Running   0          1m
        authentik-redis-master-0              1/1     Running   0          1m
        ```
        
        *(Pod names may vary, but you should see at least server and worker. The Redis pod appears if using the bitnami sub-chart.)*
        
4.  **Check Ingress:** Verify that an Ingress resource for Authentik was created:
    
    -   `kubectl get ingress -n authentik` – you should see an ingress with host `auth.yuandrk.net`. For example:
        
        ```bash
        $ kubectl get ing -n authentik
        NAME                   CLASS    HOSTS               ADDRESS        PORTS   AGE
        authentik-server       traefik  auth.yuandrk.net    <IP/CNAME>     80,443  1m
        ```
        
        Ensure the Ingress address shows your Traefik’s IP or hostname (for a load balancer or internal address). If using Cloudflare Tunnel, the ADDRESS might show a local cluster IP (since Argo Tunnel doesn’t fill an address), which is fine as long as DNS is correct.
        
5.  **Traefik Routing:** Check Traefik’s dashboard or logs to see if it picked up the new ingress route. There should be a router for `auth.yuandrk.net`. If Traefik requires specific annotations or IngressClass, ensure those are correct. (Our HelmRelease used `ingressClassName: traefik`, which should match your setup.)
    
6.  **HelmRelease Status:** You can describe the HelmRelease for errors:  
    `kubectl describe helmrelease authentik -n authentik`.  
    Look for events or status conditions. A successful install will show messages like chart pull success, release installed, etc. If there are issues (e.g., wrong values, image pull errors, etc.), they will appear here or in pod logs.
    

**Verification Checklist:**

-    **Flux Sync:** Flux has applied the new manifests (check Flux logs or the presence of resources in the cluster).
    
-    **Pods Running:** The Authentik pods (server, worker, redis) are all **Running** and healthy. No CrashLoopBackOff or errors.
    
-    **HelmRelease Healthy:** `kubectl get helmrelease -n authentik` shows the HelmRelease is ready/healthy (and no upgrade failures).
    
-    **Ingress Created:** An Ingress for **auth.yuandrk.net** exists in namespace `authentik`. Traefik has recognized it (check Traefik dashboard or `kubectl describe ingress` for details).
    
-    **No Secrets Leaked:** Confirm that in the HelmRelease `.spec.values` (you can see it via `kubectl get helmrelease authentik -n authentik -o yaml`), the sensitive values are not present in plain form. They should either be omitted or masked, with Flux having injected them directly to the pods. (The secrets should reside only in the `authentik-credentials` Secret resource.)
    

## Phase 5: Post-Deployment Verification and Testing

Finally, verify that Authentik is functioning and accessible at the intended URL.

1.  **Initial Startup Checks:** Authentik’s server will run database migrations on first startup. Check the logs to ensure migrations succeeded and no fatal errors occurred:
    
    -   `kubectl logs deployment/authentik-server -n authentik -f` – look for messages about applying migrations and starting up.
        
    -   `kubectl logs deployment/authentik-worker -n authentik -f` – ensure the worker connects to Redis and the database properly (no auth errors).  
        Any errors connecting to the database (e.g., authentication issues) will appear here. If you see “password authentication failed” or similar, double-check the DB credentials in the Secret and that the DB user has access[reddit.com](https://www.reddit.com/r/Traefik/best/?tl=fil#:~:text=,1). If there are Redis connection issues (unlikely if using in-cluster Redis), ensure the Redis pod is running.
        
2.  **Access the Authentik UI:** In a web browser, navigate to **https://auth.yuandrk.net**. You should see the Authentik login page or setup flow. Since we provided `bootstrap_password`, Authentik will **skip the initial setup wizard** and allow direct login with the default admin. Log in with username **akadmin** and the **admin password** you set in the secret[docs.goauthentik.io](https://docs.goauthentik.io/install-config/automated-install/#:~:text=). You should be brought to the Authentik admin interface after logging in.
    
    -   If you encounter a certificate error, it means TLS isn’t properly set up. Ensure that your certificate is in place (via cert-manager or Cloudflare origin cert). If using Cloudflare’s proxy with “Flexible” SSL (not recommended), you might need to allow HTTP. Ideally use “Full (strict)” with a valid cert on Traefik.
        
    -   If the page is not reachable, check Cloudflare Tunnel status and that your DNS `auth.yuandrk.net` points to the tunnel. You may also try accessing directly if on the same network (e.g., via the Traefik service NodePort or load balancer) to rule out tunnel issues.
        
3.  **Functional Tests:** After logging in, verify basic functionality:
    
    -   Navigate the Authentik UI, ensure you can access the **Providers** and **Outposts** sections, etc.
        
    -   (Optional) Create a test user or run an outpost if needed, just to validate the system can write to the database and communicate with Redis.
        
4.  **Inspect Configuration (Optional):** You can further verify that Authentik picked up your configuration by dumping the running config. For example:
    
    ```bash
    kubectl exec -it -n authentik deployment/authentik-worker -c worker -- ak dump_config
    ```
    
    This will print Authentik’s effective configuration, including database settings and other env vars[docs.goauthentik.io](https://docs.goauthentik.io/install-config/configuration/#:~:text=docker%20compose%20run%20,dump_config). Check that the `POSTGRESQL` settings match what you expect (host, user, etc.), and that `SECRET_KEY` and other sensitive configs are set (they will be masked in output, but you can see if they exist).
    
5.  **Cleanup and Scaling:** If everything looks good, consider any cleanup or scaling:
    
    -   The HelmRelease by default set replicas to 1 for server and worker. In a production-grade setup, you might increase replicas for high availability once you confirm everything works (update the `server.replicas` and `worker.replicas` in values accordingly).
        
    -   If you temporarily made the Authentik service `LoadBalancer` for debugging (as some do), you can revert it to `ClusterIP` now that ingress is verified[reddit.com](https://www.reddit.com/r/selfhosted/comments/wre8ua/authentiktraefikk8sfluxcd_because_documentation/#:~:text=Everything%20defined%20in%20this%20helm,switching%20it%20back%20to%20ClusterIP)[reddit.com](https://www.reddit.com/r/selfhosted/comments/wre8ua/authentiktraefikk8sfluxcd_because_documentation/#:~:text=replicas%3A%201%20service%3A%20enabled%3A%20true,infra).
        
    -   Monitor Authentik’s logs for a while to ensure there are no errors (especially around sending emails, tasks, etc., which might indicate if SMTP or other integrations need configuration).
        

**Verification Checklist:**

-    **Web Login:** Able to reach **https://auth.yuandrk.net** in a browser and see the Authentik login page (status code 200).
    
-    **Admin Login:** Successfully logged in as `akadmin` with the provided password, and landed on the Authentik dashboard.
    
-    **Database Connected:** No errors in logs about database; tables created in the `authentik` database (you can connect to Postgres and confirm tables if desired).
    
-    **Redis Connected:** No errors about Redis in logs (if Redis was not running, the worker would log connection failures).
    
-    **Secure Secrets:** Authentik is running with the expected secret key and admin credentials, which were loaded from Kubernetes Secret (confirm via `ak dump_config` that configuration is applied[docs.goauthentik.io](https://docs.goauthentik.io/install-config/configuration/#:~:text=docker%20compose%20run%20,dump_config)).
    
-    **Ingress/TLS:** TLS is working (no browser certificate warnings) and the Traefik ingress is properly routing traffic to Authentik. Cloudflare proxy shows the site as healthy.
    
-    **Flux Compliance:** All changes were made via GitOps (no manual kubectl changes). Future modifications to Authentik (upgrades, config changes) can now be managed by editing the Git manifests and letting Flux apply them, ensuring a **production-ready GitOps workflow** 🎉.

## ✅ DEPLOYMENT COMPLETED - 2025-09-07

**Status: Successfully deployed and operational**

The complete Authentik deployment has been successfully implemented following all phases of this plan:

### Final Verification Results:
- ✅ **Phase 1-3**: PostgreSQL, base manifests, and SOPS secrets - all operational
- ✅ **Phase 4**: FluxCD deployment completed - all pods running (authentik-server, authentik-worker, authentik-redis)  
- ✅ **Phase 5**: External access via Cloudflare Tunnel successfully configured
- ✅ **Web Access**: https://auth.yuandrk.net returns proper 302 redirect to authentication flow
- ✅ **TLS Configuration**: Cloudflare Tunnel configured with HTTPS + `no_tls_verify: true` for proper X-Forwarded-Proto headers
- ✅ **Ingress**: Traefik ingress properly routing `auth.yuandrk.net` to authentik-server service

### Key Technical Resolution:
The critical issue with "interceptors did not return an alternative response" was resolved by:
1. Configuring Cloudflare Tunnel to connect via HTTPS (`https://k3s-master:443`)  
2. Adding `origin_request { no_tls_verify = true }` to handle self-signed certificates
3. This ensures Authentik receives proper `X-Forwarded-Proto: https` headers, enabling correct CSRF/cookie handling

### Production Configuration:
- **Version**: Authentik 2025.8.1 (latest stable)
- **Database**: External PostgreSQL 15.13 on k3s-worker1 with required extensions
- **Storage**: Redis cluster for sessions and cache
- **Security**: All secrets managed via SOPS encryption
- **Access**: Fully accessible via https://auth.yuandrk.net with proper SSL/TLS
- **GitOps**: Complete FluxCD integration for ongoing management

The authentication system is now ready for production use and integration with other services.
    