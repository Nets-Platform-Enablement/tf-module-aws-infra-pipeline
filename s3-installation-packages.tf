resource "aws_s3_bucket" "packages" {
  bucket        = lower("${local.name}-terraform-packages-${var.environment}")
  tags          = local.tags
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "packages" {
  bucket = aws_s3_bucket.packages.bucket
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "packages" {
  bucket = aws_s3_bucket.packages.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_versioning" "packages" {
  bucket = aws_s3_bucket.packages.id
  versioning_configuration {
    status = "Enabled"
  }
  lifecycle {
    prevent_destroy = false
  }
}

# Installation packages
################
locals {
  packages = {
    terraform = {
      target = "terraform-${var.terraform_version}.zip"
      source = "https://releases.hashicorp.com/terraform/${var.terraform_version}/terraform_${var.terraform_version}_linux_amd64.zip"
    }
    tflint-installer = {
      target = "tflint-installer.sh"
      source = "https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh"
    }
    tflint = {
      target = "tflint-${var.tflint_version}.zip"
      source = "https://github.com/terraform-linters/tflint/releases/download/v${var.tflint_version}/tflint_linux_amd64.zip"
    }
  }
}
resource "null_resource" "download_package" {
  for_each = local.packages
	
  provisioner "local-exec" {
    command = <<EOF
    curl -qL -s --retry 3 -o /tmp/${each.value.target} ${each.value.source}
    EOF
  }

  triggers = {
    target = each.value.target
    source = each.value.source
  }
} 

resource "aws_s3_object" "packages" {
  for_each  = local.packages
  bucket    = aws_s3_bucket.packages.bucket
  key       = each.value.target
  source    = "/tmp/${each.value.target}"

  depends_on = [ null_resource.download_package ]
}
