# CodePipeline

resource "aws_codestarconnections_connection" "this" {
  name          = "aws-github-connection"
  provider_type = "GitHub"
}

resource "aws_codepipeline" "terraform" {
  count    = var.require_manual_approval ? 1 : 0
  name     = "${local.name}-${var.environment}-terraform-apply"
  role_arn = aws_iam_role.codepipeline.arn
  tags     = local.tags
  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts_store.bucket
    type     = "S3"
    encryption_key {
      type  = "KMS"
      id    = aws_kms_key.codeartifact_key.key_id
    }
  }
  stage {
    name = "Clone"
    action {
      name             = local.name
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["CodeWorkspace"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.this.arn
        FullRepositoryId = var.github_repository_id
        BranchName       = var.branch_name
      }
    }
  }
  stage {
    name = "Terraform-Project-Testing"
    action {
      run_order        = 1
      name             = "tflint-linting-terraform"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["CodeWorkspace"]
      output_artifacts = []
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.tflint.name
      }
    }
  }

  stage {
    name = "Manual-Approval"
    action {
      run_order        = 1
      name             = "terraform-plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["CodeWorkspace"]
      output_artifacts = ["TerraformPlan"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.tf_plan.name
      }
    }

    action {
      run_order = 2
      name      = "plan-approval"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"

      configuration = {
        NotificationArn    = module.sns_topic.topic_arn
        CustomData         = "This will deploy following ${local.name} IAC code changes into the ${var.environment} AWS environment"
        ExternalEntityLink = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/$252Faws$252Fcodebuild$252F${local.name}-tf-plan"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      run_order        = 1
      name             = "terraform-apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["CodeWorkspace", "TerraformPlan"]
      output_artifacts = []
      version          = "1"
      configuration = {
        ProjectName   = aws_codebuild_project.tf_apply.name
        PrimarySource = "CodeWorkspace"
      }
    }
  }
  artifact_store {
    encryption_key {
      id = "aws_kms_key.codebuild_key.key_id"
    }
  }
}
