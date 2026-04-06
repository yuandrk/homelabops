# Infrastructure Architecture Diagrams

This document contains Mermaid diagrams visualizing the homelab infrastructure architecture and workflows.

## Infrastructure Layers Overview

```mermaid
graph TB
    subgraph "External Layer"
        Internet[🌐 Internet]
        CloudFlare[☁️ Cloudflare]
        DNS[🏷️ DNS Records]
        Tunnel[🚇 Cloudflare Tunnel]
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
            Ansible[⚙️ Ansible<br/>Node config]
        end
    end

    subgraph "Compute Layer"
        subgraph "k3s-master (amd64)"
            Master[🖥️ k3s-master<br/>Ubuntu 24.04<br/>10.10.0.1 / 192.168.1.223]
            Traefik[🔀 Traefik<br/>Ingress]
            PiHole[🛡️ Pi-hole<br/>Host :8081]
        end

        subgraph "k3s-worker1 (arm64)"
            Worker1[🍓 k3s-worker1<br/>Raspberry Pi<br/>10.10.0.2]
        end

        subgraph "k3s-worker2 (arm64)"
            Worker2[🍓 k3s-worker2<br/>Raspberry Pi<br/>10.10.0.4]
        end

        subgraph "k3s-worker3 (amd64, GPU)"
            Worker3[🖥️ k3s-worker3<br/>10.10.0.5]
            PostgreSQL[🐘 PostgreSQL<br/>Native]
            GPU[🎮 NVIDIA MX130]
        end
    end

    subgraph "Container Layer"
        subgraph "K3s Cluster"
            CoreDNS[🌐 CoreDNS]
            FluxCD[🔄 FluxCD v2<br/>GitOps Controller]

            subgraph "apps namespace"
                OpenWebUI[🤖 Open-WebUI<br/>llm.yuandrk.net]
                Ollama[🧠 Ollama]
                Pipelines[🔗 Pipelines]
                Immich[🖼️ Immich<br/>photos.yuandrk.net]
                ActualBudget[💰 ActualBudget<br/>budget.yuandrk.net]
                UptimeKuma[📊 Uptime Kuma<br/>uptime.yuandrk.net]
                N8N[⚙️ n8n<br/>n8n.yuandrk.net]
                PgAdmin[🐘 pgAdmin<br/>pgadmin.yuandrk.net]
            end

            subgraph "kube-system namespace"
                Headlamp[🎛️ Headlamp<br/>headlamp.yuandrk.net]
                NvidiaPlugin[🎮 nvidia-device-plugin<br/>DaemonSet]
            end

            subgraph "monitoring namespace"
                Prometheus[📈 Prometheus<br/>10Gi PVC, 15d]
                Grafana[📊 Grafana<br/>grafana.yuandrk.net]
                NodeExporter[📊 Node Exporter]
                KubeStateMetrics[📊 Kube State Metrics]
                Loki[📜 Loki<br/>10Gi PVC]
                Alloy[🚛 Alloy<br/>Log collector DaemonSet]
            end

            subgraph "storage namespace"
                NFSProv[🗄️ NFS Subdir Provisioner<br/>storageclass: nfs-immich]
            end
        end
    end

    subgraph "Data Layer"
        subgraph "Storage"
            LocalPath[💾 local-path<br/>Default StorageClass]
            NFS[🗄️ NFS<br/>Immich 500Gi]
            HostStorage[🗄️ /var/lib/rancher/k3s]
        end

        subgraph "External"
            GitRepo[📚 GitHub<br/>yuandrk/homelabops]
            HelmCharts[📦 Helm Charts<br/>various repos]
        end
    end

    %% External
    Internet --> CloudFlare
    CloudFlare --> DNS
    CloudFlare --> Tunnel
    Tunnel --> Master

    %% Network
    Router --> Switch
    Switch --> Master
    Switch --> Worker1
    Switch --> Worker2
    Switch --> Worker3

    %% Infra
    Terraform --> S3
    Terraform --> OIDC
    Terraform --> CloudFlare
    Ansible --> Master
    Ansible --> Worker1
    Ansible --> Worker2
    Ansible --> Worker3

    %% Orchestration
    Master --> CoreDNS
    Master --> Traefik
    Master --> FluxCD
    FluxCD --> GitRepo
    FluxCD --> HelmCharts

    %% Storage
    Immich --> NFS
    OpenWebUI --> LocalPath
    LocalPath --> HostStorage
    PostgreSQL --> Worker3

    %% App connections
    OpenWebUI --> Ollama
    OpenWebUI --> Pipelines
    Immich --> PostgreSQL

    %% Service exposure
    Traefik --> OpenWebUI
    Traefik --> Immich
    Traefik --> ActualBudget
    Traefik --> UptimeKuma
    Traefik --> N8N
    Traefik --> PgAdmin
    Traefik --> Grafana
    Traefik --> Headlamp

    classDef external fill:#e1f5fe
    classDef network fill:#f3e5f5
    classDef infra fill:#e8f5e8
    classDef compute fill:#fff3e0
    classDef container fill:#fce4ec
    classDef data fill:#f1f8e9

    class Internet,CloudFlare,DNS,Tunnel external
    class Router,Switch network
    class S3,OIDC,Terraform,Ansible infra
    class Master,Worker1,Worker2,Worker3,Traefik,PiHole,PostgreSQL,GPU compute
    class CoreDNS,FluxCD,OpenWebUI,Ollama,Pipelines,Immich,ActualBudget,UptimeKuma,N8N,PgAdmin,Headlamp,NvidiaPlugin,Prometheus,Grafana,NodeExporter,KubeStateMetrics,Loki,Alloy,NFSProv container
    class LocalPath,NFS,HostStorage,GitRepo,HelmCharts data
```

## Network Flow Diagram

```mermaid
flowchart LR
    subgraph "External Access"
        User[👤 User]
        Domain[🌐 *.yuandrk.net]
    end

    subgraph "Cloudflare"
        CF_DNS[📋 DNS]
        CF_Tunnel[🚇 Tunnel]
        CF_Proxy[🛡️ Proxy & WAF]
    end

    subgraph "Homelab Network (10.10.0.0/24 LAN)"
        Master_Node[🖥️ k3s-master<br/>10.10.0.1]
        Worker1_Node[🍓 k3s-worker1<br/>10.10.0.2]
        Worker2_Node[🍓 k3s-worker2<br/>10.10.0.4]
        Worker3_Node[🖥️ k3s-worker3 GPU<br/>10.10.0.5]
    end

    subgraph "K3s Ingress Path"
        Traefik_LB[🔀 Traefik<br/>k3s-master:80/443]
        Ingress[📥 Ingress<br/>Host-based routing]
        Service[🔌 ClusterIP Service]
        Pod[📦 Application Pod]
    end

    %% External flow
    User --> Domain
    Domain --> CF_DNS
    CF_DNS --> CF_Proxy
    CF_Proxy --> CF_Tunnel
    CF_Tunnel --> Master_Node

    %% Internal K3s flow
    Master_Node --> Traefik_LB
    Traefik_LB --> Ingress
    Ingress --> Service
    Service --> Pod

    %% Cluster network
    Master_Node -.-> Worker1_Node
    Master_Node -.-> Worker2_Node
    Master_Node -.-> Worker3_Node

    classDef external fill:#e3f2fd
    classDef cloudflare fill:#ff9800,color:#fff
    classDef network fill:#e8f5e8
    classDef k3s fill:#fce4ec

    class User,Domain external
    class CF_DNS,CF_Tunnel,CF_Proxy cloudflare
    class Master_Node,Worker1_Node,Worker2_Node,Worker3_Node network
    class Traefik_LB,Ingress,Service,Pod k3s
```

## GitOps Workflow

```mermaid
gitGraph
    commit id: "main branch"
    branch dev
    checkout dev
    commit id: "dev branch"

    branch feature/some-app
    checkout feature/some-app
    commit id: "Add app config"
    commit id: "Tune values"

    checkout dev
    merge feature/some-app
    commit id: "Merge to dev"

    checkout main
    merge dev
    commit id: "Release to prod"
```

## FluxCD Reconciliation Flow

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant GitHub as 📚 GitHub Repo
    participant FluxCD as 🔄 FluxCD Controller
    participant K8s as ☸️ Kubernetes API
    participant Apps as 🚀 Applications

    Dev->>GitHub: 1. Push changes to main
    Note over GitHub: Repository updated

    FluxCD->>GitHub: 2. Poll repository (1m interval)
    GitHub-->>FluxCD: 3. Return latest commit

    alt New changes detected
        FluxCD->>FluxCD: 4. Build manifests
        FluxCD->>K8s: 5. Apply resources
        K8s-->>FluxCD: 6. Confirm deployment

        FluxCD->>Apps: 7. Update applications
        Apps-->>FluxCD: 8. Report status
    else No changes
        FluxCD->>FluxCD: 4. Skip reconciliation
    end

    Note over FluxCD,Apps: Continuous monitoring & drift detection
```

## Service Architecture

```mermaid
graph TB
    subgraph "External Services (yuandrk.net)"
        Chat[🤖 llm]
        Photos[🖼️ photos]
        Budget[💰 budget]
        N8nExt[⚙️ n8n]
        PgAdminExt[🐘 pgadmin]
        Uptime[📊 uptime]
        HeadlampExt[🎛️ headlamp]
        GrafanaExt[📊 grafana]
        PiholeExt[🛡️ pihole]
        Webhook[🔗 flux-webhook]
    end

    subgraph "Cloudflare Tunnel"
        CFT[🚇 cloudflared]
    end

    subgraph "Routing Targets"
        TraefikSvc[🔀 Traefik<br/>k3s-master:80]
        PiholeHost[🛡️ Pi-hole FTL<br/>127.0.0.1:8081]
        WebhookNP[🔗 Flux Webhook<br/>k3s-worker1:30080]
    end

    subgraph "K3s apps namespace"
        OpenWebuiApp[🤖 open-webui]
        OllamaApp[🧠 ollama]
        PipelinesApp[🔗 pipelines]
        ImmichApp[🖼️ immich]
        ActualApp[💰 actualbudget]
        N8nApp[⚙️ n8n]
        PgAdminApp[🐘 pgadmin]
        UptimeApp[📊 uptime-kuma]
    end

    subgraph "Other Namespaces"
        HeadlampApp[🎛️ headlamp<br/>kube-system]
        GrafanaApp[📊 grafana<br/>monitoring]
    end

    subgraph "Storage Backends"
        LocalPV[💾 local-path PVCs]
        NFSPV[🗄️ NFS 500Gi<br/>Immich]
        PG[🐘 PostgreSQL<br/>worker3 native]
    end

    %% External → Tunnel
    Chat --> CFT
    Photos --> CFT
    Budget --> CFT
    N8nExt --> CFT
    PgAdminExt --> CFT
    Uptime --> CFT
    HeadlampExt --> CFT
    GrafanaExt --> CFT
    PiholeExt --> CFT
    Webhook --> CFT

    %% Tunnel → routes
    CFT --> TraefikSvc
    CFT --> PiholeHost
    CFT --> WebhookNP

    %% Traefik → apps
    TraefikSvc --> OpenWebuiApp
    TraefikSvc --> ImmichApp
    TraefikSvc --> ActualApp
    TraefikSvc --> N8nApp
    TraefikSvc --> PgAdminApp
    TraefikSvc --> UptimeApp
    TraefikSvc --> HeadlampApp
    TraefikSvc --> GrafanaApp

    %% App internals
    OpenWebuiApp --> OllamaApp
    OpenWebuiApp --> PipelinesApp

    %% Storage
    OpenWebuiApp --> LocalPV
    PipelinesApp --> LocalPV
    ActualApp --> LocalPV
    UptimeApp --> LocalPV
    N8nApp --> LocalPV
    PgAdminApp --> LocalPV
    ImmichApp --> NFSPV
    ImmichApp --> PG
    N8nApp --> PG

    classDef external fill:#e3f2fd
    classDef tunnel fill:#ff9800,color:#fff
    classDef host fill:#fff3e0
    classDef k8s fill:#fce4ec
    classDef storage fill:#f1f8e9

    class Chat,Photos,Budget,N8nExt,PgAdminExt,Uptime,HeadlampExt,GrafanaExt,PiholeExt,Webhook external
    class CFT tunnel
    class PiholeHost,TraefikSvc,WebhookNP host
    class OpenWebuiApp,OllamaApp,PipelinesApp,ImmichApp,ActualApp,N8nApp,PgAdminApp,UptimeApp,HeadlampApp,GrafanaApp k8s
    class LocalPV,NFSPV,PG storage
```

## Node Architecture & Workload Placement

```mermaid
graph TB
    subgraph "amd64 Nodes"
        MasterNode[🖥️ k3s-master<br/>Ubuntu 24.04<br/>4 cores / 16Gi RAM]
        Worker3Node[🖥️ k3s-worker3<br/>Ubuntu 24.04<br/>8 cores / 16Gi RAM<br/>NVIDIA MX130]

        subgraph "Master Workloads"
            TraefikWorkload[🔀 Traefik]
            FluxWorkload[🔄 FluxCD controllers]
            OpenWebUIWorkload[🤖 open-webui<br/>nodeAffinity: amd64]
        end

        subgraph "Worker3 Workloads"
            ImmichWorkload[🖼️ immich-server]
            ImmichML[🧠 immich-machine-learning<br/>GPU-accelerated]
            OllamaWorkload[🧠 ollama]
            PostgresHost[🐘 PostgreSQL native]
        end
    end

    subgraph "arm64 Nodes (Raspberry Pi)"
        Worker1Node[🍓 k3s-worker1<br/>4 cores / 4Gi RAM]
        Worker2Node[🍓 k3s-worker2<br/>4 cores / 4Gi RAM]

        subgraph "Pi Workloads"
            LightApps[⚡ Lightweight apps<br/>uptime-kuma, actualbudget,<br/>pgadmin, n8n]
            SystemPods[📦 System DaemonSets<br/>node-exporter, alloy]
        end
    end

    subgraph "Scheduling"
        Affinity[📋 Constraints<br/>• amd64 affinity for ML/LLM<br/>• GPU label: nvidia.com/gpu=true<br/>• PVC RWO pins to one node]
    end

    MasterNode --> TraefikWorkload
    MasterNode --> FluxWorkload
    MasterNode --> OpenWebUIWorkload

    Worker3Node --> ImmichWorkload
    Worker3Node --> ImmichML
    Worker3Node --> OllamaWorkload
    Worker3Node --> PostgresHost

    Worker1Node --> LightApps
    Worker1Node --> SystemPods
    Worker2Node --> LightApps
    Worker2Node --> SystemPods

    Affinity --> OpenWebUIWorkload
    Affinity --> ImmichML

    classDef amd64 fill:#e3f2fd
    classDef arm64 fill:#fff3e0
    classDef workload fill:#fce4ec
    classDef rule fill:#f1f8e9

    class MasterNode,Worker3Node,TraefikWorkload,FluxWorkload,OpenWebUIWorkload,ImmichWorkload,ImmichML,OllamaWorkload,PostgresHost amd64
    class Worker1Node,Worker2Node,LightApps,SystemPods arm64
    class Affinity rule
```
