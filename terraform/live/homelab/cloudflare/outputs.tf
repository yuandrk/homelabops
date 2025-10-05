output "tunnel_services" {
  description = "Information about all tunnel services"
  value = {
    for service_name, service_config in module.tunnel_dns : service_name => {
      hostname     = service_config.hostname
      tunnel_cname = service_config.tunnel_cname
      tunnel_id    = service_config.tunnel_id
    }
  }
}

# Separate outputs for convenience
output "pihole_url" {
  description = "Pi-hole public URL"
  value       = "https://${module.tunnel_dns["pihole"].hostname}"
}

output "budget_url" {
  description = "Budget app public URL"
  value       = "https://${module.tunnel_dns["budget"].hostname}"
}

output "n8n_url" {
  description = "n8n public URL"
  value       = "https://${module.tunnel_dns["n8n"].hostname}"
}

# Tunnel token for cloudflared daemon (sensitive)
output "tunnel_token" {
  description = "Token for cloudflared daemon (same for all services)"
  value       = module.tunnel_dns["pihole"].tunnel_token
  sensitive   = true
}

# List of all hostnames in the correct order
output "all_hostnames" {
  description = "List of all configured hostnames in priority order"
  value       = [for service in local.tunnel_services : service.hostname]
}

# Tunnel config information
output "tunnel_config" {
  description = "Tunnel configuration details"
  value = {
    tunnel_id     = local.tunnel_id
    ingress_rules = length(local.tunnel_services)
    services      = [for service in local.tunnel_services : service.name]
    order         = "priority-based (list order)"
  }
}
