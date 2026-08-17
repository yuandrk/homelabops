# Infrastructure Architecture Diagrams

This document contains Mermaid diagrams visualizing the homelab infrastructure architecture and workflows.

> Last verified against the live cluster on 2026-06-11 (K3s v1.33.5+k3s1, 3 nodes).
> Deployed app versions drift — check live with `kubectl get deploy -A -o wide` rather than trusting docs.

## Infrastructure Layers Overview

```mermaid
graph TB
    subgraph "External Layer"
        Internet[🌐 Internet]
        CloudFlare[☁️ Cloudflare<br/>DNS + Proxy + Tunnel edge]
    end

    subgraph "Network Layer"
        Router[🏠 BT Router<br/>192.168.1.0/24]
        Switch[🔀 Gigabit Switch<br/>10.10.0.0/24 LAN]
    end

    subgraph "Infrastructure Layer"
        subgraph "AWS"
            S3[🪣 S3 Bucket<br/>terraform-state<br/>native locking]
            OIDC[🔐 GitHub OIDC<br/>CI/CD auth]
        end

        subgraph "Management Tools"
            Terraform[🏗️ Terraform<br/>IaC via GitHub Actions]
            Ansible[⚙️ Ansible<br/>Node config, SSH :2222]
        end
    end

    subgraph "Compute Layer"
        Master[🖥️ k3s-master<br/>amd64, Ubuntu 24.04, 4c/16Gi<br/>10.10.0.1 / 192.168.1.223]
        Worker1[🍓 k3s-worker1<br/>Raspberry Pi arm64, 4c/4Gi<br/>10.10.0.2 / 192.168.1.137<br/>NFS server /srv/nfs/immich]
        Worker3[🖥️ k3s-worker3<br/>amd64, 8c/16Gi<br/>10.10.0.5<br/>PostgreSQL native · MX130 GPU idle]
    end

    subgraph "Container Layer (K3s Cluster)"
        CoreDNS[🌐 CoreDNS]
        Traefik[🔀 Traefik<br/>Ingress controller]
        FluxCD[🔄 FluxCD v2<br/>GitOps controllers]

        subgraph "apps namespace"
            Immich[🖼️ Immich<br/>server + ML + valkey<br/>photos.yuandrk.net]
            ActualBudget[💰 ActualBudget<br/>budget.yuandrk.net]
            N8N[⚙️ n8n<br/>n8n.yuandrk.net]
            QBit[⬇️ qBittorrent<br/>qbit.home.yuandrk.net · tailnet only]
        end

        subgraph "networking namespace"
            Cloudflared[🚇 cloudflared<br/>2 replicas, outbound tunnel]
        end

        subgraph "kube-system namespace"
            Headlamp[🎛️ Headlamp<br/>headlamp.yuandrk.net]
            MetricsServer[📐 metrics-server]
            LocalPathProv[💾 local-path-provisioner]
        end

        subgraph "monitoring namespace"
            Prometheus[📈 Prometheus<br/>10Gi PVC, 15d]
            Grafana[📊 Grafana<br/>grafana.yuandrk.net]
            NodeExporter[📊 Node Exporter<br/>DaemonSet]
            KubeStateMetrics[📊 Kube State Metrics<br/>+ flux-kube-state-metrics]
            Loki[📜 Loki<br/>10Gi PVC + loki-canary]
            Alloy[🚛 Alloy<br/>Log collector DaemonSet]
        end

        subgraph "storage namespace"
            NFSProv[🗄️ NFS Subdir Provisioner<br/>storageclass: nfs-immich]
        end

        subgraph "onepassword namespace"
            OnePassword[🔑 1Password Connect<br/>+ operator]
        end
    end

    subgraph "Data Layer"
        subgraph "Storage"
            LocalPath[💾 local-path<br/>Default StorageClass]
            NFS[🗄️ NFS export on worker1<br/>10.10.0.2:/srv/nfs/immich<br/>Immich 500Gi RWX]
            PostgreSQL[🐘 PostgreSQL<br/>native on worker3<br/>10.10.0.5:5432]
        end

        subgraph "External"
            GitRepo[📚 GitHub<br/>yuandrk/homelabops]
            HelmCharts[📦 Helm Charts<br/>various repos]
        end
    end

    %% External — cloudflared dials OUT to Cloudflare edge
    Internet --> CloudFlare
    Cloudflared -->|outbound tunnel| CloudFlare
    Cloudflared --> Traefik

    %% Network
    Router --> Switch
    Switch --> Master
    Switch --> Worker1
    Switch --> Worker3

    %% Infra
    Terraform --> S3
    Terraform --> OIDC
    Terraform --> CloudFlare
    Ansible --> Master
    Ansible --> Worker1
    Ansible --> Worker3

    %% Orchestration
    FluxCD --> GitRepo
    FluxCD --> HelmCharts

    %% Storage & data
    Immich --> NFS
    Immich --> PostgreSQL
    N8N --> PostgreSQL
    LocalPath --> LocalPathProv
    NFSProv --> NFS

    %% Service exposure
    Traefik --> Immich
    Traefik --> ActualBudget
    Traefik --> N8N
    Traefik --> Grafana
    Traefik --> Headlamp

    classDef external fill:#e1f5fe
    classDef network fill:#f3e5f5
    classDef infra fill:#e8f5e8
    classDef compute fill:#fff3e0
    classDef container fill:#fce4ec
    classDef data fill:#f1f8e9

    class Internet,CloudFlare external
    class Router,Switch network
    class S3,OIDC,Terraform,Ansible infra
    class Master,Worker1,Worker3 compute
    class CoreDNS,Traefik,FluxCD,Immich,ActualBudget,N8N,QBit,Cloudflared,Headlamp,MetricsServer,LocalPathProv,Prometheus,Grafana,NodeExporter,KubeStateMetrics,Loki,Alloy,NFSProv,OnePassword container
    class LocalPath,NFS,PostgreSQL,GitRepo,HelmCharts data
```

## Network Flow Diagram

External traffic never hits the nodes directly: the cloudflared pods open **outbound** connections to Cloudflare's edge, and requests come back down that tunnel to in-cluster Service DNS.

```mermaid
flowchart LR
    subgraph "External Access"
        User[👤 User]
        Domain[🌐 *.yuandrk.net]
    end

    subgraph "Cloudflare"
        CF_DNS[📋 DNS<br/>CNAME → tunnel]
        CF_Proxy[🛡️ Proxy & WAF]
        CF_Edge[🚇 Tunnel edge]
    end

    subgraph "K3s Cluster (10.10.0.0/24 LAN)"
        Cloudflared[🚇 cloudflared ×2<br/>networking ns<br/>pods on master + worker1]
        TraefikSvc[🔀 traefik.kube-system.svc:80]
        WebhookSvc[🔗 webhook-receiver<br/>flux-system.svc:80]
        Ingress[📥 Ingress<br/>Host-based routing]
        Service[🔌 ClusterIP Service]
        Pod[📦 Application Pod]
    end

    %% External flow
    User --> Domain
    Domain --> CF_DNS
    CF_DNS --> CF_Proxy
    CF_Proxy --> CF_Edge
    Cloudflared -.->|outbound connection| CF_Edge
    CF_Edge -->|via tunnel| Cloudflared

    %% Internal routing
    Cloudflared -->|"*.yuandrk.net"| TraefikSvc
    Cloudflared -->|flux-webhook.yuandrk.net| WebhookSvc
    TraefikSvc --> Ingress
    Ingress --> Service
    Service --> Pod

    classDef external fill:#e3f2fd
    classDef cloudflare fill:#ff9800,color:#fff
    classDef k3s fill:#fce4ec

    class User,Domain external
    class CF_DNS,CF_Proxy,CF_Edge cloudflare
    class Cloudflared,TraefikSvc,WebhookSvc,Ingress,Service,Pod k3s
```

Non-tunnel access paths: Traefik listens on node ports 80/443 via svclb (addresses 192.168.1.223 / 192.168.1.137) and on k3s-master's Tailscale address `100.96.117.64`. Hosts under `*.home.yuandrk.net` resolve to that Tailscale address, so they work from any tailnet device and nowhere else. immich-server is additionally exposed on NodePort `30283` for the mobile app.

## GitOps Workflow

Trunk-based: short-lived feature branches and Renovate PRs merge into `main`; there is no `dev` branch. Flux deploys from `main`, Terraform applies from `main` via GitHub Actions.

```mermaid
flowchart LR
    subgraph "Authoring"
        Feature[🌿 feature branch]
        Renovate[🤖 Renovate branch<br/>dependency bumps]
    end

    subgraph "GitHub"
        PR[🔀 Pull Request]
        Main[📚 main branch]
        PlanCI[📋 terraform-plan.yml<br/>on PR, terraform paths]
        ApplyCI[🚀 terraform-apply.yml<br/>on push to main<br/>env: homelab approval]
    end

    subgraph "Delivery"
        Flux[🔄 Flux<br/>poll main @1m<br/>+ flux-webhook push]
        Cluster[☸️ K3s cluster<br/>self-healing]
        Cloudflare[☁️ Cloudflare<br/>DNS + tunnel config]
    end

    Feature --> PR
    Renovate --> PR
    PR --> PlanCI
    PR -->|merge| Main
    Main --> ApplyCI
    ApplyCI --> Cloudflare
    Main --> Flux
    Flux --> Cluster

    classDef branch fill:#e8f5e8
    classDef gh fill:#e3f2fd
    classDef delivery fill:#fce4ec

    class Feature,Renovate branch
    class PR,Main,PlanCI,ApplyCI gh
    class Flux,Cluster,Cloudflare delivery
```

## FluxCD Reconciliation Flow

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant GitHub as 📚 GitHub Repo
    participant Webhook as 🔗 webhook-receiver
    participant FluxCD as 🔄 FluxCD Controllers
    participant K8s as ☸️ Kubernetes API
    participant Apps as 🚀 Applications

    Dev->>GitHub: 1. Merge PR to main

    par Push notification (fast path)
        GitHub->>Webhook: 2a. Webhook via flux-webhook.yuandrk.net
        Webhook->>FluxCD: Trigger source reconcile
    and Polling (fallback)
        FluxCD->>GitHub: 2b. Poll repository (1m interval)
    end

    GitHub-->>FluxCD: 3. Return latest commit

    alt New changes detected
        FluxCD->>FluxCD: 4. Build manifests per Kustomization
        FluxCD->>K8s: 5. Apply resources
        K8s-->>FluxCD: 6. Confirm deployment
        FluxCD->>Apps: 7. Update applications (incl. HelmReleases)
        Apps-->>FluxCD: 8. Report status
    else No changes
        FluxCD->>FluxCD: 4. Skip reconciliation
    end

    Note over FluxCD,Apps: Continuous drift detection — manual kubectl edits are reverted
```

Kustomizations: `flux-system`, `apps`, `infrastructure`, `infrastructure-networking`, `monitoring-controllers`, `monitoring-configs`, `secrets`, `storage`.

## Service Architecture

```mermaid
graph TB
    subgraph "External Services (yuandrk.net)"
        Photos[🖼️ photos]
        Budget[💰 budget]
        N8nExt[⚙️ n8n]
        HeadlampExt[🎛️ headlamp]
        GrafanaExt[📊 grafana]
        Webhook[🔗 flux-webhook]
    end

    subgraph "Cloudflare Tunnel"
        CFT[🚇 cloudflared<br/>networking ns, 2 replicas]
    end

    subgraph "Routing Targets"
        TraefikSvc[🔀 Traefik<br/>traefik.kube-system.svc:80]
        WebhookSvc[🔗 webhook-receiver<br/>flux-system.svc:80]
    end

    subgraph "K3s apps namespace"
        ImmichApp[🖼️ immich-server<br/>+ NodePort 30283]
        ImmichML[🧠 immich-machine-learning<br/>CPU]
        Valkey[⚡ immich-valkey<br/>Redis-compatible cache]
        ActualApp[💰 actualbudget]
        N8nApp[⚙️ n8n]
        QBitApp[⬇️ qbittorrent<br/>k3s-master only]
    end

    subgraph "Other Namespaces"
        HeadlampApp[🎛️ headlamp<br/>kube-system]
        GrafanaApp[📊 grafana<br/>monitoring]
    end

    subgraph "Storage Backends"
        LocalPV[💾 local-path PVCs<br/>actualbudget 5Gi · n8n 5Gi<br/>immich-ml 10Gi · qbittorrent 1Gi]
        MediaHost[📼 hostPath /srv/media<br/>k3s-master]
        NFSPV[🗄️ NFS 500Gi RWX<br/>worker1 10.10.0.2:/srv/nfs/immich]
        PG[🐘 PostgreSQL native<br/>worker3 10.10.0.5:5432]
    end

    %% External → Tunnel
    Photos --> CFT
    Budget --> CFT
    N8nExt --> CFT
    HeadlampExt --> CFT
    GrafanaExt --> CFT
    Webhook --> CFT

    %% Tunnel → routes
    CFT --> TraefikSvc
    CFT --> WebhookSvc

    %% Traefik → apps
    TraefikSvc --> ImmichApp
    TraefikSvc --> ActualApp
    TraefikSvc --> N8nApp
    TraefikSvc --> HeadlampApp
    TraefikSvc --> GrafanaApp

    %% Immich internals
    ImmichApp --> ImmichML
    ImmichApp --> Valkey

    %% Storage
    ActualApp --> LocalPV
    N8nApp --> LocalPV
    QBitApp --> LocalPV
    QBitApp --> MediaHost
    ImmichML --> LocalPV
    ImmichApp --> NFSPV
    ImmichApp --> PG
    N8nApp --> PG

    classDef external fill:#e3f2fd
    classDef tunnel fill:#ff9800,color:#fff
    classDef host fill:#fff3e0
    classDef k8s fill:#fce4ec
    classDef storage fill:#f1f8e9

    class Photos,Budget,N8nExt,HeadlampExt,GrafanaExt,Webhook external
    class CFT tunnel
    class TraefikSvc,WebhookSvc host
    class ImmichApp,ImmichML,Valkey,ActualApp,N8nApp,QBitApp,HeadlampApp,GrafanaApp k8s
    class LocalPV,NFSPV,PG storage
```

## Node Architecture & Workload Placement

Placement below reflects the live cluster; only the Immich stack is pinned (nodeAffinity to k3s-worker3 in its HelmRelease). Everything else is scheduler-placed and may move — RWO local-path PVCs then pin a pod to wherever its volume was created.

```mermaid
graph TB
    subgraph "k3s-master (amd64, 4c/16Gi)"
        MasterNode[🖥️ control-plane<br/>10.10.0.1 / 192.168.1.223]
        MasterWork[🔀 Traefik · CoreDNS · Headlamp<br/>🔄 Flux core controllers<br/>⚙️ n8n · ⬇️ qBittorrent<br/>🚇 cloudflared replica<br/>🤖 Hermes agent + gateway — outside k3s]
    end

    subgraph "k3s-worker1 (arm64 Raspberry Pi, 4c/4Gi)"
        Worker1Node[🍓 worker + NFS server<br/>10.10.0.2 / 192.168.1.137<br/>exports /srv/nfs/immich]
        Worker1Work[💰 actualbudget<br/>📐 metrics-server · 💾 local-path-provisioner<br/>📊 kube-state-metrics ×2<br/>🗄️ nfs-subdir-provisioner<br/>🔄 image-automation-controller<br/>🚇 cloudflared replica]
    end

    subgraph "k3s-worker3 (amd64, 8c/16Gi, MX130)"
        Worker3Node[🖥️ worker<br/>10.10.0.5<br/>🐘 PostgreSQL native<br/>🎮 GPU labeled, unused — no device plugin]
        Worker3Work[🖼️ immich-server · 🧠 immich-ml CPU · ⚡ immich-valkey<br/>📈 Prometheus · 📊 Grafana · 📜 Loki<br/>⚙️ prometheus-operator]
    end

    subgraph "Every node (DaemonSets)"
        DS[🚛 alloy · 📊 node-exporter<br/>🐤 loki-canary · ⚖️ svclb-traefik]
    end

    subgraph "Scheduling Constraints"
        Affinity[📋 Immich stack → k3s-worker3<br/>nodeAffinity in HelmRelease<br/>colocated with native PostgreSQL<br/>📋 RWO local-path PVCs pin pods to one node]
    end

    MasterNode --> MasterWork
    Worker1Node --> Worker1Work
    Worker3Node --> Worker3Work
    Affinity --> Worker3Work

    classDef amd64 fill:#e3f2fd
    classDef arm64 fill:#fff3e0
    classDef workload fill:#fce4ec
    classDef rule fill:#f1f8e9

    class MasterNode,Worker3Node amd64
    class Worker1Node arm64
    class MasterWork,Worker1Work,Worker3Work,DS workload
    class Affinity rule
```
