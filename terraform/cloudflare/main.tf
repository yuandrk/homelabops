data "cloudflare_zone" "root" {
  zone_id = var.cloudflare_zone_id      
}

# Define all services in one place for easy management
locals {
  tunnel_services = {
    pihole = {
      hostname = "pihole.yuandrk.net"
      service  = "http://127.0.0.1:80"
    }
    budget = {
      hostname = "budget.yuandrk.net"
      service  = "http://127.0.0.1:5006"
    }
    # Examples for future services:
    # grafana = {
    #   hostname = "grafana.yuandrk.net"
    #   service  = "http://127.0.0.1:3000"
    # }
  }
  
  tunnel_id = "4a6abf9a-d178-4a56-9586-a3d77907c5f1"
}

# Create only DNS records for each service
module "tunnel_dns" {
  source   = "../modules/tunnel"
  for_each = local.tunnel_services

  account_id = var.cloudflare_account_id
  zone_id    = data.cloudflare_zone.root.zone_id

  existing_tunnel_id = local.tunnel_id
  hostname           = each.value.hostname
  service            = each.value.service  # this parameter is not used in the updated module
}

# One common tunnel configuration for ALL services
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = local.tunnel_id

  config = {
    ingress = concat(
      # Create an ingress rule for each service
      [
        for service in local.tunnel_services : {
          hostname = service.hostname
          service  = service.service
        }
      ],
      # Mandatory catch-all rule at the end
      [{
        service = "http_status:404"
      }]
    )
  }
}
