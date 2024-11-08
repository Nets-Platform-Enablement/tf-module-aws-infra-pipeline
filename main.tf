terraform {
  required_version = ">= 1.9"
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

  # Nets-Platform-Enamblement/Project-Name -> Project-Name
  name = element(
    split("/", var.github_repository_id),
    length(split("/", var.github_repository_id)) - 1
  )

  tfvars            = var.variables_file == "" ? "environments/${var.environment}.tfvars" : var.variables_file
  terraform_version = var.terraform_version != "" ? var.terraform_version : "1.9.3"
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
