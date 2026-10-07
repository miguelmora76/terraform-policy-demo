locals {
  # Keep in sync with CHANGELOG.md and the git tag (CI checks CHANGELOG).
  module_version = "1.0.0"

  tags = merge(var.tags, {
    Environment   = var.environment
    Owner         = var.owner
    ManagedBy     = "terraform"
    ModuleVersion = local.module_version
  })
}

resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.expiration_days == null ? 0 : 1
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = var.expiration_days
    }
  }
}
