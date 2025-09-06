variable "aws_region" {
  description = "Región (solo para validate/scan)."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Bucket fuente."
  type        = string
  default     = "iac-security-demo-logs-example"
}

variable "access_log_bucket_name" {
  description = "Bucket para access logs."
  type        = string
  default     = "iac-security-demo-access-logs-example"
}

variable "replica_bucket_name" {
  description = "Bucket destino de replicación."
  type        = string
  default     = "iac-security-demo-replica-example"
}
