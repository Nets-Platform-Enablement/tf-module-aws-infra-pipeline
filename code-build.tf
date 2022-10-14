# CodeBuild

#CloudWatch to log files
resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  name = "${local.name}-logs"

  tags = merge(local.tags,
  {
    Application = local.name
  })
  retention_in_days = 7
}
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
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    #buildspec = "${path.module}/files/buildspec_tflint.yml"
    buildspec = "${file("${path.module}/files/buildspec_tflint.yml")}"
  }
}


resource "aws_codebuild_project" "checkov" {
  name         = "${local.name}-checkov"
  description  = "Managed using Terraform"
  service_role = aws_iam_role.codebuild.arn
  tags         = local.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${path.module}/files/buildspec_checkov.yml"
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
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "VAR_FILE"
      value = local.tfvars
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${path.module}/files/buildspec_tf_plan.yml"
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
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "VAR_FILE"
      value = local.tfvars
    }
  }
  
  source {
    type      = "CODEPIPELINE"
    buildspec = "${path.module}/files/${var.require_manual_approval ? "buildspec_tf_apply.yml" : "buildspec_tf_apply_auto_approve.yml"}"
  }
}
