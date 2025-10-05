terraform {
  backend "s3" {
    bucket  = "terraform-state-homelab-yuandrk"
    key     = "cloudflare/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true

    # Use S3 native locking (no DynamoDB needed)
    use_lockfile = true
  }
}
