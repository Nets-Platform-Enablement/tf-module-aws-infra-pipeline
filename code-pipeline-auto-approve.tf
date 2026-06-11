locals {
  checks = {
    "tflint" = {
      name        = "tflint"
      ProjectName = aws_codebuild_project.tflint.name
    }
    "checkov" = var.enable_checkov ? {
      name        = "checkov"
      ProjectName = aws_codebuild_project.checkov.name
    } : null
  }
}

resource "aws_codepipeline" "terraform_without_approval" {
  count    = !var.require_manual_approval && local.use_legacy_pipeline ? 1 : 0
  name     = substr("${local.name}-${var.environment}-terraform-apply", 0, 100)
  role_arn = aws_iam_role.codepipeline.arn
  tags     = local.tags
  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts_store.bucket
    type     = "S3"
    encryption_key {
      type = "KMS"
      id   = aws_kms_key.codeartifact_key.key_id
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
    dynamic "action" {
      for_each = var.enable_checkov ? [local.checks.tflint, local.checks.checkov] : [local.checks.tflint]
      content {
        run_order        = action.key + 1
        name             = action.value.name
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        input_artifacts  = ["CodeWorkspace"]
        output_artifacts = []
        version          = "1"
        configuration = {
          ProjectName = action.value.ProjectName
        }
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
      input_artifacts  = ["CodeWorkspace"]
      output_artifacts = []
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.tf_apply.name
      }
    }
  }
}

resource "aws_codepipeline" "terraform_without_approval_optimized" {
  count    = !var.require_manual_approval && local.use_optimized_pipeline ? 1 : 0
  name     = substr("${local.name}-${var.environment}-terraform-apply", 0, 100)
  role_arn = aws_iam_role.codepipeline.arn
  tags     = local.tags
  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts_store.bucket
    type     = "S3"
    encryption_key {
      type = "KMS"
      id   = aws_kms_key.codeartifact_key.key_id
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

  dynamic "stage" {
    for_each = local.manage_custom_codebuild_image ? [1] : []
    content {
      name = "Prepare-CodeBuild-Image"
      action {
        run_order        = 1
        name             = "codebuild-image"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        input_artifacts  = ["CodeWorkspace"]
        output_artifacts = []
        version          = "1"
        configuration = {
          ProjectName = aws_codebuild_project.codebuild_image[0].name
        }
      }
    }
  }

  stage {
    name = "Validate-And-Plan"
    action {
      run_order        = 1
      name             = "validate-plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["CodeWorkspace"]
      output_artifacts = ["TerraformPlan"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.validate_plan[0].name
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
}
