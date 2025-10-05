provider "github" {
  token = var.github_token
  owner = var.github_owner
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "flux" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
  git = {
    url = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
    branch = var.git_branch
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

resource "flux_bootstrap_git" "this" {
  depends_on = [tls_private_key.flux]
  
  path            = "clusters/prod"
  version         = var.flux_version
  components_extra = ["image-reflector-controller", "image-automation-controller"]
}

resource "tls_private_key" "flux" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "flux" {
  title      = "Flux"
  repository = var.repository_name
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false
}
