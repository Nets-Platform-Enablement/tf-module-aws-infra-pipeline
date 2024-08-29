# CodeBuild

#Validate terraform
resource "aws_codebuild_project" "tflint" {
  name         = "${local.name}-tflint"
  description  = "Managed using Terraform"
  service_role = aws_iam_role.codebuild.arn
  tags         = local.tags
  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = var.codebuild_image_id
    type         = "LINUX_CONTAINER"
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile(
      "${path.module}/files/buildspec_tflint.yml.tftpl",
      {
        TF_VERSION = local.terraform_version,
        DIRECTORY  = var.directory,
        BACKENDFILE = var.tfbackend_file
      }
    )
  }
}

#Do show and plan for dry run Terraform
resource "aws_codebuild_project" "tf_plan" {
  name         = "${local.name}-tf-plan"
  description  = "Managed using Terraform"
  service_role = aws_iam_role.codebuild.arn
  tags         = local.tags
  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = var.codebuild_image_id
    type         = "LINUX_CONTAINER"
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
        TF_VERSION  = local.terraform_version,
        DIRECTORY   = var.directory,
        EXTRA_FILES = var.extra_build_artifacts,
        BACKENDFILE = var.tfbackend_file
      }
    )
  }
}

resource "aws_codebuild_project" "tf_apply" {
  name         = "${local.name}-tf-apply"
  description  = "Managed using Terraform"
  service_role = aws_iam_role.codebuild.arn
  tags         = local.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = var.codebuild_image_id
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "VAR_FILE"
      value = local.tfvars
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile(
      "${path.module}/files/${var.require_manual_approval ? "buildspec_tf_apply.yml.tftpl" : "buildspec_tf_apply_auto_approve.yml.tftpl"}",
      {
        TF_VERSION = local.terraform_version,
        DIRECTORY  = var.directory,
        BACKENDFILE = var.tfbackend_file
      }
    )
  }
}
