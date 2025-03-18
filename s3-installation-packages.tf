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
  latest_version_urls = var.terraform_version != "latest" && var.tflint_version != "latest" ? {} : {
    tflint    = var.tflint_version == "latest" ? "https://api.github.com/repos/terraform-linters/tflint/releases/latest" : null
    terraform = var.terraform_version == "latest" ? "https://api.github.com/repos/hashicorp/terraform/releases/latest" : null
  }
}
# Query for the 'latest' version of terraform/tflint
data "http" "latest_release" {
  for_each = { for k, v in local.latest_version_urls : k => v if v != null }

  url = each.value

  # Optional request headers
  request_headers = {
    Accept     = "application/json"
    User-Agent = "Terraform"
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
  # Only decode JSON when using "latest"
  tflint_latest    = var.tflint_version == "latest" ? jsondecode(data.http.latest_release["tflint"].response_body).name : null
  terraform_latest = var.terraform_version == "latest" ? jsondecode(data.http.latest_release["terraform"].response_body).name : null

  # Use provided versions or latest
  tflint_version    = var.tflint_version == "latest" ? local.tflint_latest : "v${var.tflint_version}"
  terraform_version = var.terraform_version == "latest" ? substr(local.terraform_latest, 1, -1) : var.terraform_version

  # Define package URLs, we do not need to download windows version as pipeline will run on linux
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

# Download packages locally
resource "null_resource" "download_package" {
  for_each = local.packages

  provisioner "local-exec" {
    command = <<EOF
    ${chomp(
    coalesce(
      # Windows PowerShell command
      startswith(pathexpand("~"), "/") ? null : "$tempPath = Join-Path $env:TEMP '${each.value.target}'; $maxRetries = 3; $retryCount = 0; do { try { Invoke-WebRequest -Uri '${each.value.source}' -OutFile $tempPath -ErrorAction Stop; Write-Host \"Downloaded to: $tempPath\"; break } catch { $retryCount++; if ($retryCount -eq $maxRetries) { throw } Start-Sleep -Seconds 3 } } while ($retryCount -lt $maxRetries)",
      # Linux/Unix command
      "curl -qL -s --retry 3 -o /tmp/${each.value.target} ${each.value.source} && echo 'Downloaded to: /tmp/${each.value.target}'"
    )
)}
    EOF
interpreter = startswith(pathexpand("~"), "/") ? [] : ["powershell", "-Command"]
}

triggers = {
  always_run = timestamp() # Ensures this runs every time
  target     = each.value.target
  source     = each.value.source
}
}

# upload packages to S3
resource "aws_s3_object" "packages" {
  for_each = local.packages
  bucket   = aws_s3_bucket.packages.bucket
  key      = each.value.target
  source   = startswith(pathexpand("~"), "/") ? "/tmp/${each.value.target}" : "${pathexpand("~/AppData/Local/Temp/")}${"/"}${each.value.target}"

  depends_on = [null_resource.download_package]
}
