variable "use_lambda_codebuild" {
  description = "If true, use Lambda-based CodeBuild compute type (30min max duration). Default is standard Linux container."
  type        = bool
  default     = false
}
# CodeBuild
locals {
  terraform_package = "${aws_s3_bucket.packages.bucket}/${local.packages.terraform.target}"
  tflint_package    = "${aws_s3_bucket.packages.bucket}/${local.packages.tflint.target}"
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
    compute_type = var.use_lambda_codebuild ? "BUILD_LAMBDA_2GB" : "BUILD_GENERAL1_SMALL"
    image        = var.codebuild_image_id
    type         = var.use_lambda_codebuild ? "LINUX_LAMBDA_CONTAINER" : "LINUX_CONTAINER"
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
        TF_SOURCE     = local.terraform_package,
        TFLINT_SOURCE = local.tflint_package,
        DIRECTORY     = var.directory,
        BACKENDFILE   = var.tfbackend_file,
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
    compute_type = var.use_lambda_codebuild ? "BUILD_LAMBDA_2GB" : "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = var.use_lambda_codebuild ? "LINUX_LAMBDA_CONTAINER" : "LINUX_CONTAINER"
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
    compute_type = var.use_lambda_codebuild ? "BUILD_LAMBDA_2GB" : "BUILD_GENERAL1_SMALL"
    image        = var.codebuild_image_id
    type         = var.use_lambda_codebuild ? "LINUX_LAMBDA_CONTAINER" : "LINUX_CONTAINER"
    environment_variable {
      name  = "VAR_FILE"
      value = local.tfvars
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile(
      "${path.module}/files/buildspec_tf_plan.yml.tftpl",
      {
        TF_SOURCE   = local.terraform_package,
        DIRECTORY   = var.directory,
        EXTRA_FILES = var.extra_build_artifacts,
        BACKENDFILE = var.tfbackend_file
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
    compute_type = var.use_lambda_codebuild ? "BUILD_LAMBDA_2GB" : "BUILD_GENERAL1_SMALL"
    image        = var.codebuild_image_id
    type         = var.use_lambda_codebuild ? "LINUX_LAMBDA_CONTAINER" : "LINUX_CONTAINER"
    environment_variable {
      name  = "VAR_FILE"
      value = local.tfvars
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
        TF_SOURCE   = local.terraform_package,
        DIRECTORY   = var.directory,
        BACKENDFILE = var.tfbackend_file
      }
    )
  }
}
