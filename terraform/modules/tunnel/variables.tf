variable "account_id"  { 
  type        = string
  description = "Cloudflare Account ID"
}

variable "zone_id" { 
  type        = string
  description = "Zone yuandrk.net"
}

variable "existing_tunnel_id" { 
  type        = string
  description = "ID of existing tunnel to use"
  default     = "4a6abf9a-d178-4a56-9586-a3d77907c5f1"
}

variable "hostname" { 
  type        = string
  description = "Public hostname (e.g., pihole.yuandrk.net)"
}

variable "service" { 
  type        = string
  description = "Backend service URL (e.g., http://10.0.0.5:80)"
}
