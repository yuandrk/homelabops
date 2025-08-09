data "cloudflare_zone" "root" {
  zone_id = var.cloudflare_zone_id      
}

locals {
  # List of services with guaranteed order
  tunnel_services = [
    {
      name     = "pihole"
      hostname = "pihole.yuandrk.net"
      service  = "http://127.0.0.1:8081"
    },
    {
      name     = "budget"
      hostname = "budget.yuandrk.net"
      service  = "http://k3s-master:80"
    },
    {
      name     = "n8n"
      hostname = "n8n.yuandrk.net"
      service  = "http://127.0.0.1:5678"
    },
    {
      name     = "flux-webhook"
      hostname = "flux-webhook.yuandrk.net"
      service  = "http://k3s-worker1:30080"
    },
    {
      name     = "chat"
      hostname = "chat.yuandrk.net"
      service  = "http://k3s-master:80"
    },
    {
      name     = "grafana"
      hostname = "grafana.yuandrk.net"
      service  = "http://k3s-master:80"
    }
  ]
  
  #
  tunnel_services_map = {
    for service in local.tunnel_services : service.name => {
      hostname = service.hostname
      service  = service.service
    }
  }
  
  tunnel_id = "4a6abf9a-d178-4a56-9586-a3d77907c5f1"
}

# DNS records for each service
module "tunnel_dns" {
  source   = "../modules/tunnel"
  for_each = local.tunnel_services_map

  account_id = var.cloudflare_account_id
  zone_id    = data.cloudflare_zone.root.zone_id

  existing_tunnel_id = local.tunnel_id
  hostname           = each.value.hostname
  service            = each.value.service
}

# Tunnel configuration - use the list directly
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = local.tunnel_id

  config = {
    ingress = concat(
      [
        for service in local.tunnel_services : {
          hostname = service.hostname
          service  = service.service
        }
      ],
      [{
        service = "http_status:404"
      }]
    )
  }
}
