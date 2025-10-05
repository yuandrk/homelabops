variable "github_actions_role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "GitHubActionsTerraformRole"
}

variable "github_repos_branches" {
  description = "List of GitHub repository branches allowed to assume the role (format: org/repo:ref:refs/heads/branch)"
  type        = list(string)
  default = [
    "yuandrk/homelabops:ref:refs/heads/main"
  ]
}

variable "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}
