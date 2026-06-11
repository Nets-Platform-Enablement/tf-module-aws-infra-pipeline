terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.72.0"
    }
  }
}

locals {
  tags = merge(var.tags, {
    Module = "tf-module-aws-infra-pipeline"
  })

  repo_name = element(
    split("/", var.github_repository_id),
    length(split("/", var.github_repository_id)) - 1
  )
  # If the 'name' is given, use it. Otherwise take the 'name' from github repository name
  name   = coalesce(var.name, local.repo_name)
  tfvars = coalesce(var.variables_file, "environments/${var.environment}.tfvars")

  use_legacy_pipeline    = var.pipeline_design == "legacy"
  use_optimized_pipeline = var.pipeline_design == "optimized"
  use_custom_codebuild_image = (
    local.use_optimized_pipeline &&
    var.enable_custom_codebuild_image
  )
  manage_custom_codebuild_image = local.use_custom_codebuild_image && var.custom_codebuild_image_uri == ""
  custom_codebuild_image_tag = lower(join("-", [
    "tf",
    replace(local.terraform_version, ".", "-"),
    "tflint",
    replace(local.tflint_version, ".", "-"),
    "checkov",
    replace(var.checkov_version, ".", "-")
  ]))
  managed_codebuild_image_uri = local.manage_custom_codebuild_image ? "${aws_ecr_repository.codebuild_image[0].repository_url}:${local.custom_codebuild_image_tag}" : ""
  codebuild_runtime_image     = local.use_custom_codebuild_image ? coalesce(var.custom_codebuild_image_uri, local.managed_codebuild_image_uri) : var.codebuild_image_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy" "managed_default" {
  for_each = toset([
    "IAMFullAccess",
    "AWSCodePipeline_FullAccess",
    "AWSCodeBuildAdminAccess",
    "AWSCodeStarFullAccess",
  ])

  name = each.value
}

data "aws_iam_policy" "managed" {
  for_each = var.managed_policies
  name     = each.value
}
