resource "aws_s3_bucket" "codepipeline_artifacts_store" {
  bucket        = lower("${local.name}-artifact-store-${var.environment}")
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

resource "aws_s3_bucket_lifecycle_configuration" "codepipeline_artifacts_store_bucket_versioning_config" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.codepipeline_artifacts_store_bucket_versioning]

  bucket = aws_s3_bucket.codepipeline_artifacts_store.id

  rule {
    id = "AllObjects"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline_artifacts_store_public_access" {
  bucket                  = aws_s3_bucket.codepipeline_artifacts_store.id
  restrict_public_buckets = true
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_policy" "artifact_store_policy" {
  bucket = aws_s3_bucket.codepipeline_artifacts_store.id
  policy = data.aws_iam_policy_document.allow_ssl_requests_only.json
}

data "aws_iam_policy_document" "allow_ssl_requests_only" {
  statement {

    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      aws_s3_bucket.codepipeline_artifacts_store.arn,
      "${aws_s3_bucket.codepipeline_artifacts_store.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

# S3 Event notificactions for bucket
resource "aws_s3_bucket_notification" "artifact_store_bucket_notificaction" {
  bucket = aws_s3_bucket.codepipeline_artifacts_store.id
  topic {
    topic_arn = module.sns_topic.sns_topic_arn
    events    = ["s3:ObjectRemoved:*"] # Permanently deleted, Delete marker created
  }
  depends_on = [
    # SNS Topic policy needs to be deployed before notifications can be set up
    aws_sns_topic_policy.terraform_updates
  ]
}
