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
  latest_version_urls = {
    tflint : "https://api.github.com/repos/terraform-linters/tflint/releases/latest"
    terraform : "https://api.github.com/repos/hashicorp/terraform/releases/latest"
  }
}
# Query for the 'latest' version of terraform/tflint
data "http" "latest_release" {
  for_each = local.latest_version_urls

  url = each.value

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
  lifecycle {
    postcondition {
      condition     = contains([200, 201, 204, 304], self.status_code)
      error_message = "Could not get latest ${each.key} version"
    }
  }
}

locals {
  # GitHub returns the version numbers with prefixed "v", terraform package URL does not have it, tflint has
  tflint_latest    = jsondecode(data.http.latest_release["tflint"].response_body).name
  terraform_latest = jsondecode(data.http.latest_release["terraform"].response_body).name
  # var.tflint_version = "latest" -> "v0.54.0"
  # var.tflint_version = "0.54.0" -> "v0.54.0"
  tflint_version = var.tflint_version == "latest" ? local.tflint_latest : "v${var.tflint_version}"
  # "v1.98.0" -> "1.98.0"
  terraform_version = var.terraform_version == "latest" ? substr(local.terraform_latest, 1, -1) : var.terraform_version

  packages = {
    terraform = {
      target = "terraform-${local.terraform_version}.zip"
      source = "https://releases.hashicorp.com/terraform/${local.terraform_version}/terraform_${local.terraform_version}_linux_amd64.zip"
    }
    tflint = {
      target = "tflint-${local.tflint_version}.zip"
      source = "https://github.com/terraform-linters/tflint/releases/download/${local.tflint_version}/tflint_linux_amd64.zip"
    }
  }
}


# locals {
#   is_windows = can(regex("\\\\", coalesce(env("HOMEPATH", ""), env("HOME", ""))))
# }
locals {
  is_windows = can(regex("Windows_NT", env("OS", "")))
}


# Download packages locally
resource "null_resource" "download_package" {
  for_each = local.packages

  provisioner "local-exec" {
    command = local.is_windows ? "curl -o $env:Temp\\${each.value.target} ${each.value.source}" : "curl -qL -s --retry 3 -o /tmp/${each.value.target} ${each.value.source}"
  }

  triggers = { # Re-download package if source or version number has changed
    target = each.value.target
    source = each.value.source
  }
}

# upload packages to S3
resource "aws_s3_object" "packages" {
  for_each = local.packages
  bucket   = aws_s3_bucket.packages.bucket
  key      = each.value.target
  source   = local.is_windows ? "${env("Temp")}\\${each.value.target}" : "/tmp/${each.value.target}"

  depends_on = [null_resource.download_package]

  lifecycle {
    ignore_changes = [source]
  }
}
