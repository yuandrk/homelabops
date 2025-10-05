terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket  = "terraform-state-homelab-yuandrk"
    key     = "fluxcd/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true

    # Use S3 native locking (no DynamoDB needed)
    use_lockfile = true
  }
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}
