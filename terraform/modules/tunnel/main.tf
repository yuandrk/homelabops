locals {
  tunnel_id = var.existing_tunnel_id
}

###############
# 1. DNS Record for this particular service
###############
resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  name    = split(".", var.hostname)[0] # "pihole" or "budget" ... 
  content = "${local.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

###############
# 2. Data source for tunnel token
###############
data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.account_id
  tunnel_id  = local.tunnel_id
}
