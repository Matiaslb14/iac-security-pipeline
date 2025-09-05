variable "aws_region" {
  description = "AWS region for validation purposes (no deploy)."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name for the logs."
  type        = string
  default     = "iac-security-demo-logs-example"
}
