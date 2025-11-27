# PostgreSQL Database (k3s-worker1) - ARCHIVED

> **⚠️ MIGRATION NOTICE**: PostgreSQL has been migrated to k3s-worker3 (Native installation)
> **Status**: ❌ ARCHIVED - This document is for historical reference only
> **Migration Date**: November 2025
> **Current Location**: See [PostgreSQL-Migration-to-Worker3.md](PostgreSQL-Migration-to-Worker3.md)
>
> **Old Configuration (k3s-worker1 - DECOMMISSIONED)**:
> **Host**: `k3s-worker1`
> **OS**: Ubuntu 24.04 LTS
> **Arch**: ARM64 (Raspberry Pi 4)
> **RAM**: 3.7 GiB
> **Storage**: 954 GiB USB-SSD
> **IP (LAN)**: `10.10.0.2`
> **Deployment**: Docker Compose (not K3s-managed)
> **PostgreSQL Version**: 15.13
> **Status**: DECOMMISSIONED (pgAdmin removed for resource optimization)

---
## 📦 Services

### PostgreSQL
- **Image**: `postgres:15.13`
- **Port**: `5432` (exposed to LAN)
- **Data**: Persisted in named volume `pgdata`
- **Env**: Username, password, database from `.env`
- **Status**: ✅ Running and stable

### ~~pgAdmin~~ (Removed)
- **Reason**: Resource optimization for Raspberry Pi 4 stability
- **Impact**: Web UI access removed, direct PostgreSQL connection required
- **Alternative**: Command-line tools (`psql`) or external database clients

---

## 🐳 docker-compose.yml (Current)

```yaml
version: "3.8"

services:
  postgres:
    container_name: postgres
    image: postgres:15.13
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PW}
      - POSTGRES_DB=${POSTGRES_DB}
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    restart: always

volumes:
  pgdata:
```

### Removed Components
```yaml
# pgAdmin service and volume removed for resource optimization:
# - pgadmin service (dpage/pgadmin4:9.2.0)
# - pgadmin_data volume
# - Port 5959 exposure
```

---

## 🔌 Database Access Methods

Since pgAdmin was removed, here are current access options:

### Direct PostgreSQL Connection
```bash
# From any LAN device
psql -h 10.10.0.2 -p 5432 -U ${POSTGRES_USER} -d ${POSTGRES_DB}

# From k3s-worker1 locally  
docker exec -it postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
```

### External Database Clients
- **DBeaver**: Configure connection to `10.10.0.2:5432`
- **VS Code**: PostgreSQL extension with connection to `10.10.0.2:5432`

### Application Connections
- **n8n**: Currently uses PostgreSQL for workflow data storage
- **Connection String**: `postgresql://${POSTGRES_USER}:${POSTGRES_PW}@10.10.0.2:5432/${POSTGRES_DB}`

---

## 📝 Management Commands

```bash
# On k3s-worker1 (/home/yuandrk/db_docker_compose/)
sudo docker compose up -d          # Start services
sudo docker compose down           # Stop services
sudo docker compose ps             # Check status
sudo docker compose logs postgres  # View PostgreSQL logs

# Database backup (manual)
docker exec postgres pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > backup_$(date +%Y%m%d).sql
```

---

## 🚀 Future: pgAdmin in K3s

**Better approach**: Deploy pgAdmin as K3s workload instead of Docker:
- Resource isolation and limits
- Ingress integration with Cloudflare tunnels  
- GitOps management via FluxCD
- No impact on database host stability
- Example: `apps/pgadmin/helm-release.yaml`

---

##  **Prompt Context (LLM)**
A PostgreSQL database is deployed via Docker Compose on k3s-worker1, a Raspberry Pi 4 (ARM64, 3.7 GiB RAM) running Ubuntu 24.04. PostgreSQL (port 5432) stores data in a persistent Docker volume (pgdata) and is accessible at `10.10.0.2:5432`.

**pgAdmin was removed** for resource optimization to prevent system instability on the Pi. Database access is now via direct PostgreSQL connections, command-line tools, or external database clients. Future plan is to deploy pgAdmin as a K3s workload for better resource management.

The PostgreSQL stack is **not managed by K3s**, but the host is part of a K3s cluster. The PostgreSQL service is intended to be **long-running**, without container resource limits.

Access is LAN-only, and no automated backups are currently configured (📝 future task). Environment variables and credentials are stored in `/home/yuandrk/db_docker_compose/.env`.

Currently used by **n8n** for workflow storage. Additional PostgreSQL roles may be created later for application integration.
