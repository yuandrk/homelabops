# Використовуємо hardcoded tunnel ID
locals {
  tunnel_id = var.existing_tunnel_id
}

###############
# 1. DNS Record (імпортуємо існуючий)
###############
resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  name    = split(".", var.hostname)[0]  # "pihole"
  content = "${local.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"  
  ttl     = 1
  proxied = true
}

###############
# 2. Tunnel Configuration (керуємо через Terraform)
###############
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = local.tunnel_id

  config = {
    ingress = [
      {
        hostname = var.hostname
        service  = var.service
      },
      {
        # Default catch-all rule (required)
        service = "http_status:404"
      }
    ]
  }
}

###############
# 3. Data source to get tunnel token
###############
data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.account_id
  tunnel_id  = local.tunnel_id
}
