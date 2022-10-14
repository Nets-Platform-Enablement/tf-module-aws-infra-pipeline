resource "aws_s3_bucket" "codepipeline_artifacts_store" {
  bucket        = "${local.name}-artifact-store-${var.environment}"
  tags          = local.tags
  force_destroy = true
}

resource "aws_s3_bucket_acl" "codepipeline_artifacts_store_acl" {
  bucket = aws_s3_bucket.codepipeline_artifacts_store.bucket
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifacts_store" {
  bucket = aws_s3_bucket.codepipeline_artifacts_store.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}
resource "aws_s3_bucket_versioning" "codepipeline_artifacts_store_bucket_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts_store.id
  versioning_configuration {
    status = "Enabled"
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline_artifacts_store_public_access" {
  bucket                  = aws_s3_bucket.codepipeline_artifacts_store.id
  restrict_public_buckets = true
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
}
