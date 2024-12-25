provider "flux" {
  kubernetes = {
    config_path = "${var.kubeconfig_path}"
  }
  git = {
    url  = "https://github.com/${var.github_owner}/${var.repository_name}.git"
    http = {
      username    = "git"
      password    = var.github_token
    }
  }
}

resource "flux_bootstrap_git" "this" {
  path = "./clusters"
}

module "github_repository"  {
  source                   = "github.com/den-vasyliev/tf-github-repository"
  github_owner             = var.github_owner
  github_token             = var.github_token
  repository_name          = var.repository_name
  public_key_openssh       = module.tls_private_key.public_key_openssh
  public_key_openssh_title = "flux"
}
module "tls_private_key" {
  source = "github.com/den-vasyliev/tf-hashicorp-tls-keys"
}