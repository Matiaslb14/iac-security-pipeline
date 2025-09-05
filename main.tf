terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider block kept generic; no credentials needed for validation/linting
provider "aws" {
  region = var.aws_region
}

# Example resource: S3 bucket with secure defaults
resource "aws_s3_bucket" "logs" {
  bucket = var.bucket_name
  force_destroy = false
}

# Bucket versioning (good practice)
resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption (good practice)
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encrypt" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access block (good practice)
resource "aws_s3_bucket_public_access_block" "logs_pab" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------------------------------------------------
# Demo: Uncomment to trigger security findings with Checkov
# ----------------------------------------------------------
# resource "aws_s3_bucket" "insecure_demo" {
#   bucket = "${var.bucket_name}-demo-public"
#   force_destroy = true  # risky in production
# }
#
# resource "aws_s3_bucket_acl" "insecure_acl" {
#   bucket = aws_s3_bucket.insecure_demo.id
#   acl    = "public-read"  # will trigger "public bucket" finding
# }
