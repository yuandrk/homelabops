data "cloudflare_zone" "root" {
  zone_id = var.cloudflare_zone_id
}

locals {
  # List of services with guaranteed order
  tunnel_services = [
    {
      name     = "budget"
      hostname = "budget.yuandrk.net"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    },
    {
      name     = "n8n"
      hostname = "n8n.yuandrk.net"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    },
    {
      name     = "flux-webhook"
      hostname = "flux-webhook.yuandrk.net"
      service  = "http://webhook-receiver.flux-system.svc.cluster.local:80"
    },
    {
      name     = "grafana"
      hostname = "grafana.yuandrk.net"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    },
    {
      name     = "headlamp"
      hostname = "headlamp.yuandrk.net"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    },
    {
      name     = "photos"
      hostname = "photos.yuandrk.net"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    },
    {
      name     = "fleet"
      hostname = "fleet.yuandrk.net"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    },
    # The Hermes dashboard is a host process on k3s-master, not a pod, so Traefik reaches it
    # through the selector-less Service in infrastructure/hermes-dashboard/base. Routing it
    # through Traefik rather than straight at 192.168.1.223:9119 is what gives it the
    # X-Forwarded-Proto middleware its OIDC login depends on.
    {
      name     = "hermes"
      hostname = "hermes.yuandrk.net"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    },
  ]

  tunnel_services_map = {
    for service in local.tunnel_services : service.name => {
      hostname    = service.hostname
      service     = service.service
      noTLSVerify = try(service.noTLSVerify, null)
    }
  }

  tunnel_id = "4a6abf9a-d178-4a56-9586-a3d77907c5f1"

  # Tailscale address of k3s-master, which is also where Traefik runs, so a single
  # wildcard covers every internal service. 100.64.0.0/10 is CGNAT and unroutable from
  # the internet. If the node ever leaves and rejoins the tailnet with a new address,
  # this is the only line to change.
  internal_ingress_ip = "100.96.117.64"
}

# DNS records for each service
resource "cloudflare_dns_record" "services" {
  for_each = local.tunnel_services_map

  zone_id = data.cloudflare_zone.root.zone_id
  name    = split(".", each.value.hostname)[0]
  content = "${local.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Internal services do not go through the tunnel. This DNS-only wildcard points
# *.home.yuandrk.net at k3s-master's Tailscale address, so any Ingress with a
# .home.yuandrk.net host is reachable from the tailnet and nowhere else. Adding an
# internal service needs no Terraform change - just the Ingress host.
#
# proxied must stay false: Cloudflare will not proxy a CGNAT address, and proxying
# would defeat the point, which is handing the client the real address.
# ttl = 1 means "automatic" and is only valid for proxied records, hence 300.
resource "cloudflare_dns_record" "internal_wildcard" {
  zone_id = data.cloudflare_zone.root.zone_id
  name    = "*.home"
  content = local.internal_ingress_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Tailscale-only ingress (k3s-master). Managed by Terraform."
}

# Tunnel configuration - use the list directly
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = local.tunnel_id

  config = {
    ingress = concat(
      [
        for service in local.tunnel_services : merge(
          {
            hostname = service.hostname
            service  = service.service
          },
          try(service.noTLSVerify, false) ? {
            origin_request = {
              no_tls_verify = service.noTLSVerify
            }
          } : {}
        )
      ],
      [{
        service = "http_status:404"
      }]
    )
  }
}
