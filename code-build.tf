# CodeBuild
locals {
  terraform_package = "${aws_s3_bucket.packages.bucket}/${local.packages.terraform.target}"
  tflint_package    = "${aws_s3_bucket.packages.bucket}/${local.packages.tflint.target}"
  # Use provided security groups or the default one we create
  codebuild_security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : (var.vpc_id != "" ? [aws_security_group.codebuild[0].id] : [])
}

# Default security group for CodeBuild (only created if VPC is used and no security groups provided)
resource "aws_security_group" "codebuild" {
  count       = var.vpc_id != "" && length(var.security_group_ids) == 0 ? 1 : 0
  name_prefix = "codebuild-${local.name}-"
  description = "Security group for CodeBuild projects in ${local.name} pipeline"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "codebuild-${local.name}" })

  # Allow all outbound traffic (required for downloading packages, accessing AWS APIs, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # No ingress rules - CodeBuild doesn't need inbound traffic
}


# Key for CodeBuild projects
resource "aws_kms_key" "codebuild" {
  description             = "Key for encrypting CodeBuild projects"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key-policy.json
  tags                    = local.tags
}
resource "aws_kms_alias" "codebuild" {
  name          = "alias/${local.name}_codebuild_key"
  target_key_id = aws_kms_key.codebuild.key_id
}

# CloudWatch logs
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "codebuild/${local.name}"
  tags              = local.tags
  retention_in_days = var.logs_retention_time
}

#Validate terraform
resource "aws_codebuild_project" "tflint" {
  name           = "${local.name}-tflint"
  description    = "Managed using Terraform"
  service_role   = aws_iam_role.codebuild.arn
  encryption_key = aws_kms_key.codebuild.arn
  tags           = local.tags
  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = var.codebuild_compute_type
    image        = var.codebuild_image_id
    type         = "LINUX_CONTAINER"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_CUSTOM_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      vpc_id             = var.vpc_id
      subnets            = var.subnet_ids
      security_group_ids = local.codebuild_security_group_ids
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "tflint"
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile(
      "${path.module}/files/buildspec_tflint.yml.tftpl",
      {
        TF_SOURCE         = local.terraform_package,
        TFLINT_SOURCE     = local.tflint_package,
        DIRECTORY         = var.directory,
        BACKENDFILE       = var.tfbackend_file,
        UPGRADE_PROVIDERS = var.terraform_init_upgrade,
      }
    )
  }
}

resource "aws_codebuild_project" "checkov" {
  name           = "${local.name}-checkov"
  description    = "Managed using Terraform"
  service_role   = aws_iam_role.codebuild.arn
  encryption_key = aws_kms_key.codebuild.arn
  tags           = local.tags
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = var.codebuild_compute_type
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_CUSTOM_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      vpc_id             = var.vpc_id
      subnets            = var.subnet_ids
      security_group_ids = local.codebuild_security_group_ids
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "checkov"
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile(
      "${path.module}/files/buildspec_checkov.yml.tftpl",
      {
        TF_SOURCE       = local.terraform_package,
        CHECKOV_VERSION = var.checkov_version
        LATEST_CHECKOV  = var.checkov_version == "latest"
        SOFTFAIL        = !var.require_checkov_pass, # Notice the "!"
        DIRECTORY       = var.directory
      }
    )
  }
}

#Do show and plan for dry run Terraform
resource "aws_codebuild_project" "tf_plan" {
  name           = "${local.name}-tf-plan"
  description    = "Managed using Terraform"
  service_role   = aws_iam_role.codebuild.arn
  encryption_key = aws_kms_key.codebuild.arn
  tags           = local.tags
  artifacts {
    type = "CODEPIPELINE"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "terraform-plan"
    }
  }

  environment {
    compute_type = var.codebuild_compute_type
    image        = var.codebuild_image_id
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "VAR_FILE"
      value = local.tfvars
    }
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_CUSTOM_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      vpc_id             = var.vpc_id
      subnets            = var.subnet_ids
      security_group_ids = local.codebuild_security_group_ids
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile(
      "${path.module}/files/buildspec_tf_plan.yml.tftpl",
      {
        TF_SOURCE         = local.terraform_package,
        DIRECTORY         = var.directory,
        EXTRA_FILES       = var.extra_build_artifacts,
        BACKENDFILE       = var.tfbackend_file,
        UPGRADE_PROVIDERS = var.terraform_init_upgrade,
      }
    )
  }
}

resource "aws_codebuild_project" "tf_apply" {
  name           = "${local.name}-tf-apply"
  description    = "Managed using Terraform"
  service_role   = aws_iam_role.codebuild.arn
  encryption_key = aws_kms_key.codebuild.arn
  tags           = local.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = var.codebuild_compute_type
    image        = var.codebuild_image_id
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "VAR_FILE"
      value = local.tfvars
    }
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_CUSTOM_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      vpc_id             = var.vpc_id
      subnets            = var.subnet_ids
      security_group_ids = local.codebuild_security_group_ids
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "terraform-apply"
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile(
      "${path.module}/files/${var.require_manual_approval ? "buildspec_tf_apply.yml.tftpl" : "buildspec_tf_apply_auto_approve.yml.tftpl"}",
      {
        TF_SOURCE         = local.terraform_package,
        DIRECTORY         = var.directory,
        BACKENDFILE       = var.tfbackend_file,
        UPGRADE_PROVIDERS = var.terraform_init_upgrade,
      }
    )
  }
}
