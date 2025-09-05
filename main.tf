terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Bucket principal
resource "aws_s3_bucket" "logs" {
  bucket        = var.bucket_name
  force_destroy = false
}

# Versioning (buenas prácticas)
resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

# ENCRYPTION CON KMS (obligatorio para CKV_AWS_145)
resource "aws_kms_key" "logs_kms" {
  description         = "KMS key for S3 logs encryption"
  enable_key_rotation = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encrypt" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs_kms.arn
    }
  }
}

# Bloqueo acceso público (hardening)
resource "aws_s3_bucket_public_access_block" "logs_pab" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
