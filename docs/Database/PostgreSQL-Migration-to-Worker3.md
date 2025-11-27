# PostgreSQL Migration: k3s-worker1 (Docker) → k3s-worker3 (Native)

**Created**: 2025-11-15
**Status**: ✅ Completed
**Source**: k3s-worker1 (10.10.0.2) - Docker PostgreSQL 15.13 (OLD)
**Target**: k3s-worker3 (10.10.0.5) - Native PostgreSQL 15 (CURRENT)

## Overview

Migrate PostgreSQL database from Docker container on k3s-worker1 to native installation on k3s-worker3.

**Benefits**:
- Native performance (no Docker overhead)
- Easier maintenance and updates
- Better resource control
- Standard systemd management

## Pre-Migration Checklist

- [ ] Verify k3s-worker3 has sufficient disk space
- [ ] Backup current database from k3s-worker1
- [ ] Document all database names and users
- [ ] Identify all services using PostgreSQL (n8n, others?)
- [ ] Plan maintenance window (estimated downtime: 15-30 minutes)

## Migration Steps

### Step 1: Install PostgreSQL on k3s-worker3

```bash
# SSH to k3s-worker3
ssh k3s-worker3

# Update package lists
sudo apt update

# Install PostgreSQL (version 15 to match current)
sudo apt install -y postgresql-15 postgresql-contrib-15

# Verify installation
sudo systemctl status postgresql

# Check PostgreSQL version
psql --version
```

### Step 2: Configure PostgreSQL on k3s-worker3

```bash
# Switch to postgres user
sudo -i -u postgres

# Configure PostgreSQL to listen on all interfaces
sudo nano /etc/postgresql/15/main/postgresql.conf
```

**Edit postgresql.conf**:
```conf
# Change listen_addresses
listen_addresses = '*'

# Optional: adjust for better performance
shared_buffers = 256MB
effective_cache_size = 1GB
```

**Configure pg_hba.conf** for network access:
```bash
sudo nano /etc/postgresql/15/main/pg_hba.conf
```

**Add these lines** (after existing entries):
```conf
# Allow connections from K3s cluster network
host    all             all             10.10.0.0/24            scram-sha-256
host    all             all             10.42.0.0/16            scram-sha-256
```

**Restart PostgreSQL**:
```bash
sudo systemctl restart postgresql
sudo systemctl enable postgresql
```

### Step 3: Create Database User and Database on k3s-worker3

```bash
# On k3s-worker3, become postgres user
sudo -i -u postgres

# Create database user (replace with your credentials)
createuser --interactive --pwprompt

# Create database (replace with your database names)
createdb -O <username> <database_name>

# Test local connection
psql -U <username> -d <database_name>
```

### Step 4: Backup Database from k3s-worker1

```bash
# SSH to k3s-worker1
ssh k3s-worker1

# Create backup directory
mkdir -p ~/postgres-migration-backup
cd ~/postgres-migration-backup

# Get database credentials from .env file
cat ~/db_docker_compose/.env

# Backup all databases
docker exec postgres pg_dumpall -U <POSTGRES_USER> > full_backup_$(date +%Y%m%d_%H%M%S).sql

# Or backup specific database
docker exec postgres pg_dump -U <POSTGRES_USER> <DATABASE_NAME> > db_backup_$(date +%Y%m%d_%H%M%S).sql

# Verify backup file
ls -lh *.sql
head -20 *.sql
```

### Step 5: Transfer Backup to k3s-worker3

```bash
# From k3s-worker1, transfer backup to k3s-worker3
scp ~/postgres-migration-backup/*.sql k3s-worker3:~/

# Or from your local machine
scp k3s-worker1:~/postgres-migration-backup/*.sql k3s-worker3:~/
```

### Step 6: Restore Database on k3s-worker3

```bash
# SSH to k3s-worker3
ssh k3s-worker3

# Restore full backup (includes all databases, users, roles)
sudo -u postgres psql -f ~/full_backup_*.sql

# Or restore specific database
sudo -u postgres psql -U <username> -d <database_name> -f ~/db_backup_*.sql

# Verify restoration
sudo -u postgres psql -U <username> -d <database_name> -c "\dt"
```

### Step 7: Test Connection from K3s Pods

```bash
# From k3s-worker3 (current node), test connection
psql -h 10.10.0.5 -U <username> -d <database_name>

# From another K3s node, test remote connection
psql -h k3s-worker3 -U <username> -d <database_name>

# Or use nc to test connectivity
nc -zv k3s-worker3 5432
```

### Step 8: Update Application Configurations

**Update n8n deployment**:
```bash
# Edit n8n deployment manifest
nano apps/n8n/base/deployment.yaml
```

**Change**:
```yaml
- name: DB_POSTGRESDB_HOST
  value: "k3s-worker1"  # OLD
```

**To**:
```yaml
- name: DB_POSTGRESDB_HOST
  value: "k3s-worker3"  # NEW (or use 10.10.0.5)
```

**Commit and push changes** (FluxCD will auto-deploy):
```bash
git add apps/n8n/base/deployment.yaml
git commit -m "chore: migrate n8n database to k3s-worker3"
git push origin main

# Watch deployment
kubectl get pods -n apps -l app=n8n -w
```

### Step 9: Update /etc/hosts (if needed)

If using hostname `k3s-worker3` in configs, ensure all nodes can resolve it:
```bash
# Already present in /etc/hosts on all nodes
10.10.0.5  k3s-worker3
```

### Step 10: Verify Applications

```bash
# Check n8n pod logs
kubectl logs -n apps -l app=n8n --tail=50

# Check if n8n can connect to database
kubectl exec -n apps deployment/n8n -- nc -zv k3s-worker3 5432

# Access n8n UI and verify workflows are intact
# https://n8n.yuandrk.net
```

### Step 11: Stop Old PostgreSQL on k3s-worker1

**Only after verifying everything works!**

```bash
# SSH to k3s-worker1
ssh k3s-worker1

# Stop Docker PostgreSQL
cd ~/db_docker_compose/
sudo docker compose down

# Optional: Keep backup of Docker volume
sudo docker volume ls
# Don't remove pgdata volume yet - keep as backup!

# Optional: Disable Docker Compose from starting on boot
sudo systemctl disable docker-compose@db_docker_compose
```

### Step 12: Update Documentation

Update these files in the repository:
- `docs/Database/PostgreSQL Database – k3s-worker1.md` → Rename to archive
- Create new: `docs/Database/PostgreSQL-Native-k3s-worker3.md`
- Update: `README.md` - Update PostgreSQL location
- Update: `CLAUDE.md` - Update database references
- Update: Any network diagrams showing PostgreSQL location

## Rollback Plan

If migration fails, rollback is simple:

```bash
# On k3s-worker1, restart Docker PostgreSQL
cd ~/db_docker_compose/
sudo docker compose up -d

# Revert n8n deployment config
git revert <commit-hash>
git push origin main

# Verify n8n reconnects to old database
kubectl logs -n apps -l app=n8n --tail=50
```

## Post-Migration Tasks

- [ ] Update all documentation
- [ ] Remove old Docker PostgreSQL after 1 week of stable operation
- [ ] Set up automated backups on k3s-worker3
- [ ] Configure log rotation for PostgreSQL logs
- [ ] Set up monitoring for PostgreSQL (Prometheus exporter)
- [ ] Document new backup procedures

## Backup Strategy (Post-Migration)

### Automated Daily Backups

Create cron job on k3s-worker3:
```bash
# Create backup script
sudo nano /usr/local/bin/postgres-backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup all databases
sudo -u postgres pg_dumpall > $BACKUP_DIR/full_backup_$DATE.sql

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/full_backup_$DATE.sql"
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/postgres-backup.sh

# Add to crontab
sudo crontab -e
```

Add line:
```cron
0 2 * * * /usr/local/bin/postgres-backup.sh
```

## Estimated Timeline

- **Preparation**: 15 minutes
- **Installation & Configuration**: 20 minutes
- **Backup & Transfer**: 10 minutes
- **Restore & Testing**: 15 minutes
- **Application Updates**: 10 minutes
- **Verification**: 15 minutes
- **Total**: ~1.5 hours

## Notes

- Native PostgreSQL uses standard paths: `/var/lib/postgresql/15/main`
- Configuration files: `/etc/postgresql/15/main/`
- Logs: `/var/log/postgresql/postgresql-15-main.log`
- Service management: `systemctl status postgresql`

## References

- PostgreSQL 15 Documentation: https://www.postgresql.org/docs/15/
- Ubuntu PostgreSQL Guide: https://help.ubuntu.com/community/PostgreSQL
