variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-west-2"
}

variable "aws_s3_bucket_name" {
  description = "The name of the S3 bucket for Terraform state."
  type        = string
  default     = "terraform-state-homelab-yuandrk"

}
