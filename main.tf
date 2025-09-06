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

# -----------------------------
# Identidad (para KMS policy)
# -----------------------------
data "aws_caller_identity" "current" {}

# -----------------------------
# KMS keys + explicit policy
# -----------------------------
data "aws_iam_policy_document" "kms_logs_policy" {
  statement {
    sid     = "AllowRootAccountFullAccess"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  # Permisos mínimos para servicios de S3 (replicación / SSE-KMS)
  statement {
    sid = "AllowS3UseOfTheKeyForEncryption"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    resources = ["*"]
  }
}

resource "aws_kms_key" "logs_kms" {
  description         = "KMS key for S3 logs encryption (source)"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_logs_policy.json
}

data "aws_iam_policy_document" "kms_replica_policy" {
  statement {
    sid     = "AllowRootAccountFullAccessReplica"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid = "AllowS3UseOfTheKeyForEncryptionReplica"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    resources = ["*"]
  }
}

resource "aws_kms_key" "replica_kms" {
  description         = "KMS key for S3 replication destination"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_replica_policy.json
}

# -----------------------------
# Buckets (source, access-logs, replica)
# -----------------------------
resource "aws_s3_bucket" "logs" {
  bucket        = var.bucket_name
  force_destroy = false
}

resource "aws_s3_bucket" "access_logs" {
  bucket        = var.access_log_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket" "replica" {
  bucket        = var.replica_bucket_name
  force_destroy = false
}

# Public Access Block en todos
resource "aws_s3_bucket_public_access_block" "logs_pab" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "access_logs_pab" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "replica_pab" {
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning (requerido para CRR)
resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_versioning" "access_logs_versioning" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_versioning" "replica_versioning" {
  bucket = aws_s3_bucket.replica.id
  versioning_configuration { status = "Enabled" }
}

# SSE con KMS por defecto (CKV_AWS_145)
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encrypt" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs_kms.arn
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encrypt" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs_kms.arn
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica_encrypt" {
  bucket = aws_s3_bucket.replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.replica_kms.arn
    }
  }
}

# Access logging (CKV_AWS_18)
resource "aws_s3_bucket_logging" "logs_logging" {
  bucket        = aws_s3_bucket.logs.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/"
}

# Lifecycle (CKV2_AWS_61)
resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "noncurrent-to-ia-then-glacier"
    status = "Enabled"

    # ← REQUERIDO por el provider: define un filtro o un prefix (uno solo).
    filter {
      prefix = "" # aplica a todo el bucket
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# -----------------------------
# CRR (CKV_AWS_144) - Config mínima
# -----------------------------
data "aws_iam_policy_document" "replication_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication_role" {
  name               = "s3-replication-role-demo"
  assume_role_policy = data.aws_iam_policy_document.replication_assume_role.json
}

data "aws_iam_policy_document" "replication_policy" {
  statement {
    sid       = "BucketLevel"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.logs.arn]
  }

  statement {
    sid       = "ObjectRead"
    actions   = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.logs.arn}/*"]
  }

  statement {
    sid       = "ObjectWriteReplica"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:ObjectOwnerOverrideToBucketOwner"]
    resources = ["${aws_s3_bucket.replica.arn}/*"]
  }

  # KMS perms: source decrypt, dest encrypt
  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.logs_kms.arn]
  }
  statement {
    actions   = ["kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [aws_kms_key.replica_kms.arn]
  }
}

resource "aws_iam_role_policy" "replication_role_policy" {
  name   = "s3-replication-policy-demo"
  role   = aws_iam_role.replication_role.id
  policy = data.aws_iam_policy_document.replication_policy.json
}

resource "aws_s3_bucket_replication_configuration" "logs_replication" {
  bucket = aws_s3_bucket.logs.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.replica_kms.arn
      }
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.logs_versioning,
    aws_s3_bucket_versioning.replica_versioning
  ]
}

# -----------------------------
# (Opcional) Bloque inseguro para provocar fallo
# -----------------------------
# resource "aws_s3_bucket_acl" "insecure_acl" {
#   bucket = aws_s3_bucket.logs.id
#   acl    = "public-read"
# }

# --- 1) Access logging para el bucket replica ---
resource "aws_s3_bucket_logging" "replica_logging" {
  bucket        = aws_s3_bucket.replica.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "replica-access-logs/"
}

# --- 2) Lifecycle para access_logs ---
resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "access-logs-expiration"
    status = "Enabled"

    # requerido por el provider: filter o prefix (uno)
    filter {
      prefix = ""
    }

    # ejemplo simple: expirar objetos luego de 365 días
    expiration {
      days = 365
    }
  }
}

# --- 2) Lifecycle para replica ---
resource "aws_s3_bucket_lifecycle_configuration" "replica_lifecycle" {
  bucket = aws_s3_bucket.replica.id

  rule {
    id     = "replica-noncurrent-to-archive"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# --- 3) Replicación también para access_logs -> replica ---
resource "aws_s3_bucket_replication_configuration" "access_logs_replication" {
  bucket = aws_s3_bucket.access_logs.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-access-logs"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.replica_kms.arn
      }
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.access_logs_versioning,
    aws_s3_bucket_versioning.replica_versioning
  ]
}
