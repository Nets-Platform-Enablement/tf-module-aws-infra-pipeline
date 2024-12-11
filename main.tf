terraform {
  required_version = ">= 1.2.0"
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
  name      = coalesce(var.name, local.repo_name)
  tfvars    = coalesce(var.variables_file, "environments/${var.environment}.tfvars")
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
  name = each.value
}
