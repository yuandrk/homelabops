terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }
  required_providers {
    flux = {
      source = "fluxcd/flux"
      version = "1.4.0"
    }
  }
}
