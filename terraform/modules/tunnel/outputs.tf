output "tunnel_id" {
  description = "ID of the existing Cloudflare Tunnel" 
  value       = local.tunnel_id
}

output "tunnel_cname" {
  description = "CNAME value for the tunnel"
  value       = "${local.tunnel_id}.cfargotunnel.com"
}

output "hostname" {
  description = "Public hostname that routes to the service"
  value       = var.hostname
}

output "tunnel_token" {
  description = "Token for running cloudflared daemon (sensitive)"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}
