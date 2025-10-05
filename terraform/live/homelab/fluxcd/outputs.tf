output "flux_repository_url" {
  description = "The GitHub repository that Flux is bootstrapped to"
  value       = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
}

output "flux_namespace" {
  description = "The namespace where Flux is installed"
  value       = flux_bootstrap_git.this.namespace
}

output "flux_path" {
  description = "The path in the repository where Flux configurations are stored"
  value       = flux_bootstrap_git.this.path
}

output "flux_version" {
  description = "The version of Flux that was installed"
  value       = var.flux_version
}

output "private_key_pem" {
  description = "The private SSH key for repository access"
  value       = tls_private_key.flux.private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "The public SSH key for repository access (deploy key)"
  value       = tls_private_key.flux.public_key_openssh
  sensitive   = true
}
