# Uptime Kuma Setup and Configuration

## Overview

Uptime Kuma is a self-hosted monitoring service that provides real-time status monitoring for all homelab services. It offers a clean web interface for tracking uptime, response times, and service availability.

## Deployment Details

### Service Configuration
- **URL**: https://uptime.yuandrk.net
- **Image**: `louislam/uptime-kuma:1.23.15`
- **Namespace**: apps
- **Storage**: 2Gi persistent volume (`/app/data`)
- **Port**: 3001

### Resource Allocation
- **Requests**: 100m CPU, 128Mi memory
- **Limits**: 500m CPU, 512Mi memory
- **Health Checks**: HTTP liveness and readiness probes on port 3001

## Initial Setup

1. **Access the Interface**: Navigate to https://uptime.yuandrk.net
2. **First Login**: Create admin account on first access
3. **Dashboard Setup**: Configure main dashboard and notification channels

## Monitoring Configuration

### Recommended Services to Monitor

Add the following services for comprehensive homelab monitoring:

#### Internal Kubernetes Services
```
ActualBudget: https://budget.yuandrk.net (HTTP, 60s interval)
Open-WebUI: https://chat.yuandrk.net (HTTP, 60s interval)  
Grafana: https://grafana.yuandrk.net (HTTP, 300s interval)
Headlamp: https://headlamp.yuandrk.net (HTTP, 300s interval)
Pi-hole: https://pihole.yuandrk.net (HTTP, 60s interval)
```

#### Infrastructure Components
```
K3s Master: k3s-master:6443 (TCP, 60s interval)
K3s Worker 1: k3s-worker1:22 (TCP, 300s interval)
K3s Worker 2: k3s-worker2:22 (TCP, 300s interval)
PostgreSQL: k3s-worker1:5432 (TCP, 300s interval)
```

#### External Dependencies
```
Cloudflare DNS: 1.1.1.1 (Ping, 300s interval)
GitHub: https://github.com (HTTP, 600s interval)
Docker Hub: https://hub.docker.com (HTTP, 600s interval)
```

## Maintenance

### Backup Configuration
Uptime Kuma data is automatically backed up via the persistent volume:
- **Location**: `/app/data` in container
- **PVC**: `uptime-kuma-pvc` (2Gi)
- **Storage Class**: `local-path`

### Updates
Updates are managed via GitOps:
1. Update image tag in `apps/uptime-kuma/base/deployment.yaml`
2. Commit and push changes
3. FluxCD will automatically roll out the update

### Monitoring Commands

```bash
# Check pod status
kubectl get pods -n apps -l app=uptime-kuma

# View logs
kubectl logs -n apps -l app=uptime-kuma

# Check service connectivity
kubectl get svc -n apps uptime-kuma

# View ingress status
kubectl get ingress -n apps uptime-kuma

# Force restart deployment
kubectl rollout restart deployment/uptime-kuma -n apps
```

## Notification Channels

Configure notification channels for alerts:

### Recommended Channels
- **Slack/Discord**: Real-time alerts for critical services
- **Email**: Daily/weekly summary reports
- **Webhook**: Integration with other monitoring systems

### Alert Thresholds
- **Critical Services** (ActualBudget, Open-WebUI): Immediate alerts on failure
- **Infrastructure** (K3s nodes): Alert after 5-minute downtime
- **External Dependencies**: Alert after 15-minute downtime

## Integration with Grafana

Uptime Kuma can be integrated with the existing Grafana monitoring:
- Export metrics to Prometheus format (if needed)
- Create Grafana dashboard with Uptime Kuma status
- Combine with existing cluster monitoring

## Troubleshooting

### Common Issues

1. **Service Not Starting**
   ```bash
   kubectl describe pod -n apps -l app=uptime-kuma
   kubectl logs -n apps -l app=uptime-kuma
   ```

2. **Storage Issues**
   ```bash
   kubectl get pvc -n apps uptime-kuma-pvc
   kubectl describe pvc -n apps uptime-kuma-pvc
   ```

3. **Network Connectivity**
   ```bash
   kubectl exec -it -n apps deployment/uptime-kuma -- curl -I localhost:3001
   ```

4. **Ingress Issues**
   ```bash
   kubectl describe ingress -n apps uptime-kuma
   curl -I https://uptime.yuandrk.net
   ```

## Security Considerations

- **Authentication**: Always set strong admin password
- **Access Control**: Consider IP restrictions if needed
- **HTTPS**: Enforced via Cloudflare tunnel
- **Data Privacy**: All monitoring data stored locally in K3s cluster

## Support and Resources

- **Official Documentation**: https://github.com/louislam/uptime-kuma
- **Community**: GitHub Discussions and Issues
- **Configuration**: All deployment files in `apps/uptime-kuma/base/`