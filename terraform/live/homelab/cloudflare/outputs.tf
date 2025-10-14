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

# Tunnel configuration
output "tunnel_config" {
  description = "Tunnel infrastructure details"
  value = {
    tunnel_id     = local.tunnel_id
    tunnel_cname  = "${local.tunnel_id}.cfargotunnel.com"
    service_count = length(local.tunnel_services)
  }
}

# Sensitive token
output "tunnel_token" {
  description = "Token for cloudflared daemon"
  value       = module.tunnel_dns["pihole"].tunnel_token
  sensitive   = true
}
