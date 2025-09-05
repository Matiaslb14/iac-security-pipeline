variable "aws_region" {
  description = "Solo para validate/scan (no despliega)."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Nombre del bucket demo."
  type        = string
  default     = "iac-security-demo-logs-example"
}
