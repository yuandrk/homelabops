data "cloudflare_zone" "root" {
  zone_id = var.cloudflare_zone_id
}

module "homelab_tunnel" {
  source = "../modules/tunnel"

  account_id         = var.cloudflare_account_id
  zone_id            = data.cloudflare_zone.root.zone_id
  existing_tunnel_id = "4a6abf9a-d178-4a56-9586-a3d77907c5f1"

  services = {
    pihole = {
      hostname = "pihole.yuandrk.net"
      service  = "http://127.0.0.1:80"
    }
    budget = {
      hostname = "budget.yuandrk.net"
      service  = "http://127.0.0.1:5006"
    }
    # easy to add new like: 
    # grafana = {
    #   hostname = "grafana.yuandrk.net"
    #   service  = "http://127.0.0.1:3000"
    # }
    # prometheus = {
    #   hostname = "prometheus.yuandrk.net"
    #   service  = "http://127.0.0.1:9090"
    # }
  }
}
