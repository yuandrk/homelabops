terraform {
  required_version = ">= 1.8.0, < 2.0"
  required_providers {
    cloudflare = { 
      source  = "cloudflare/cloudflare" 
      version = ">= 5.3.0, < 6.0"
    }
  }
}
