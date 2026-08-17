# Single comprehensive output with all service info
output "services" {
  description = "All tunnel services with URLs and backend targets"
  value = {
    for service in local.tunnel_services : service.name => {
      url     = "https://${service.hostname}"
      backend = service.service
    }
  }
}

# Tailnet-only services (no tunnel, no public reachability)
output "internal_ingress" {
  description = "Wildcard for tailnet-only services"
  value = {
    pattern = "*.home.yuandrk.net"
    target  = local.internal_ingress_ip
  }
}

# Tunnel configuration
output "tunnel_config" {
  description = "Tunnel infrastructure details"
  value = {
    tunnel_id     = local.tunnel_id
    tunnel_cname  = "${local.tunnel_id}.cfargotunnel.com"
    service_count = length(local.tunnel_services)
  }
}
