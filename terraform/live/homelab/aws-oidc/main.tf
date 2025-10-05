# GitHub OIDC Provider for AWS authentication
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub's official thumbprints
  # https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name        = "GitHub OIDC Provider"
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name        = "GitHub Actions Terraform Role"
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# Trust policy for GitHub Actions OIDC
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        for repo_branch in var.github_repos_branches :
        "repo:${repo_branch}"
      ]
    }
  }
}

# IAM Policy for Terraform state bucket access
data "aws_iam_policy_document" "terraform_state_access" {
  # S3 bucket permissions
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.terraform_state_bucket}",
      "arn:aws:s3:::${var.terraform_state_bucket}/*"
    ]
  }

  # S3 native locking permissions
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObjectLockConfiguration",
      "s3:GetObjectLockConfiguration"
    ]
    resources = [
      "arn:aws:s3:::${var.terraform_state_bucket}"
    ]
  }
}

# Attach policy to role
resource "aws_iam_role_policy" "github_actions_terraform" {
  name   = "TerraformStateAccess"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.terraform_state_access.json
}
