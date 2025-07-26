terraform {
  backend "s3" {
    bucket         = "terraform-state-homelab-yuandrk"
    key            = "global/bootstrap.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-homelab-lock"
    encrypt        = true
  }
}
