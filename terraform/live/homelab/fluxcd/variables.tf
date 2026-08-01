variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token with repo and admin:repo_hook permissions."
  sensitive   = true
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to kubeconfig file."
  default     = "../kube/kubeconfig"
}

variable "github_owner" {
  type        = string
  description = "GitHub username or organization name for the repo."
}

variable "repository_name" {
  type        = string
  description = "Name of the repository to bootstrap Flux."
}

variable "git_branch" {
  type    = string
  default = "main"
}

variable "flux_version" {
  type        = string
  description = "FluxCD version to install. Pinned to the 2.8 line: Flux 2.9 requires Kubernetes >= v1.34.1 and this cluster runs k3s v1.33."
  default     = "v2.8.8"
}
