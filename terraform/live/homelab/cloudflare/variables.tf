variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "API token with DNS edit permissions"
}
variable "cloudflare_zone_id" {
  type        = string
  description = "Static Zone ID until provider bug is fixed"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare Account ID (not Zone ID)"
}
