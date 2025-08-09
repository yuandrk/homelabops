# Monitoring Documentation Index

**K3s Homelab Monitoring Stack Documentation**

## 📊 Overview

This directory contains comprehensive documentation for the K3s homelab monitoring infrastructure, including Prometheus, Grafana, FluxCD monitoring, and custom alerting.

## 🗂️ Documentation Structure

### **Core Documentation**
| File | Description | Status |
|------|-------------|--------|
| [Enhanced-Monitoring-Setup.md](Enhanced-Monitoring-Setup.md) | **📋 Main Guide** - Complete monitoring architecture and implementation | ✅ Current (Aug 2025) |
| [Monitoring-Stack-Overview.md](Monitoring-Stack-Overview.md) | High-level overview of monitoring components | ✅ Active |
| [Monitoring-Setup-Guide.md](Monitoring-Setup-Guide.md) | Original setup instructions | ✅ Reference |

### **Specialized Guides**
| File | Description | Use Case |
|------|-------------|----------|
| [Uptime-Kuma-Setup.md](Uptime-Kuma-Setup.md) | **🆕 Service Monitoring** - Uptime Kuma configuration and setup | Service status monitoring |
| [FluxCD-Health-Monitoring.md](FluxCD-Health-Monitoring.md) | FluxCD-specific monitoring and health checks | GitOps monitoring |
| [Flux-Dashboard-Troubleshooting.md](Flux-Dashboard-Troubleshooting.md) | Dashboard-specific issues | Dashboard problems |
| [Monitoring-Troubleshooting.md](Monitoring-Troubleshooting.md) | General monitoring troubleshooting | Legacy issues |
| [Monitoring-Troubleshooting-Guide.md](Monitoring-Troubleshooting-Guide.md) | **🚨 Quick Reference** - Common issues and solutions | Emergency fixes |

## 🚀 Quick Start

### New to the monitoring setup?
**Start here**: [Enhanced-Monitoring-Setup.md](Enhanced-Monitoring-Setup.md)

### Having issues?
**Start here**: [Monitoring-Troubleshooting-Guide.md](Monitoring-Troubleshooting-Guide.md)

### Need to understand FluxCD monitoring?
**Start here**: [FluxCD-Health-Monitoring.md](FluxCD-Health-Monitoring.md)

## 🎯 Current Status (August 2025)

### ✅ **Working Components**
- **Prometheus**: Collecting metrics from all sources
- **Grafana**: https://grafana.yuandrk.net (admin/flux)
- **Uptime Kuma**: https://uptime.yuandrk.net - Service status monitoring
- **Node Monitoring**: 3 nodes with comprehensive metrics
- **Flux Monitoring**: GitOps reconciliation and status
- **Custom Alerts**: 17 alert rules covering critical scenarios
- **Dashboards**: Node Exporter + Flux dashboards

### 📊 **Key Metrics**
- **Alert Rules**: 17 custom + 35 default kube-prometheus-stack
- **Dashboards**: Node Exporter (custom) + Flux control-plane/cluster
- **Retention**: 15 days, 10Gi storage
- **Coverage**: All K3s nodes + Flux controllers

## 🔧 Infrastructure Details

### **Cluster Architecture**
```
k3s-master  (10.10.0.1) - Control plane + monitoring
k3s-worker1 (10.10.0.2) - Worker + PostgreSQL  
k3s-worker2 (10.10.0.4) - Worker
```

### **Monitoring Stack**
```
monitoring namespace:
├── prometheus-kube-prometheus-stack-prometheus-0  (StatefulSet)
├── kube-prometheus-stack-grafana                  (Deployment)  
├── flux-kube-state-metrics                       (Custom Deployment)
├── node-exporter                                  (DaemonSet - all nodes)
└── Custom PrometheusRules + Dashboards           (ConfigMaps)
```

### **External Access**
- **Grafana**: https://grafana.yuandrk.net via Cloudflare Tunnel
- **Uptime Kuma**: https://uptime.yuandrk.net via Cloudflare Tunnel
- **Internal Prometheus**: http://10.43.40.155:9090

## 📚 Related Documentation

### **Architecture**  
- [Infrastructure Diagrams](../Architecture/Infrastructure-Diagrams.md) - Overall infrastructure
- [Network Architecture](../Network/Network-Architecture.md) - Network topology

### **Operations**
- [FluxCD Setup](../FluxCD/FluxCD-Setup.md) - GitOps deployment
- [FluxCD Troubleshooting](../FluxCD/FluxCD-Troubleshooting.md) - FluxCD issues

### **K3s Cluster**
- [K3s Deploy Summary](../K3s/k3s_deploy_summary.md) - Cluster setup
- [System Verification Report](../K3s/system_verification_report.md) - Cluster health

## 🆘 Emergency Procedures

### **Monitoring is Down**
1. Check cluster: `kubectl get nodes`
2. Check monitoring namespace: `kubectl get all -n monitoring`  
3. Access Grafana: https://grafana.yuandrk.net
4. Follow [Troubleshooting Guide](Monitoring-Troubleshooting-Guide.md)

### **Metrics Missing**
1. Check [ServiceMonitor Label Issues](Monitoring-Troubleshooting-Guide.md#prometheus-selector-issues)
2. Verify [Flux Integration](Enhanced-Monitoring-Setup.md#key-configuration-details)
3. Test [Diagnostic Queries](Monitoring-Troubleshooting-Guide.md#useful-diagnostic-queries)

### **Alerts Not Firing**
1. Verify [PrometheusRules](Enhanced-Monitoring-Setup.md#alert-rules-overview)
2. Check [Alert Thresholds](Enhanced-Monitoring-Setup.md#updating-thresholds)
3. Review Grafana → Alerting → Alert Rules

---

**📞 Support Path**: Documentation → Troubleshooting → Manual cluster inspection → SSH to k3s-master

**🔄 Last Updated**: August 2025 | **✅ Status**: Fully Operational