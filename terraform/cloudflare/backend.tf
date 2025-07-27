terraform {
  backend "s3" {
    bucket         = "terraform-state-homelab-yuandrk"
    key            = "cloudflare/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-homelab-lock"
    encrypt        = true
  }
}
