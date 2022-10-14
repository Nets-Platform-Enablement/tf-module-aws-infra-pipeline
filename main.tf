locals {
  tags = merge(var.tags, {
    Module = "tf-module-aws-infra-pipeline"
  })

  # Nets-Platform-Enamblement/Project-Name -> Project-Name
  name = element(
    split("/", var.github_repository_id), 
    length(split("/", var.github_repository_id))-1
  )

  tfvars = var.variables_file == "" ?  "environments/${var.environment}.tfvars" : var.variables_file
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy" "managed" {
  for_each = toset(
    concat(
      [
        "IAMFullAccess",
        "AWSKeyManagementServicePowerUser",
        "CloudWatchLogsFullAccess",
        "CloudWatchEventsFullAccess",
        "AWSCodePipeline_FullAccess",
        "AWSCodeStarFullAccess",
        "AWSCodeBuildAdminAccess",
        "AWSCodeArtifactAdminAccess",
        "AmazonSNSFullAccess",
      ], 
      var.managed_policies
    )
  )
  name = each.value
}
