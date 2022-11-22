# tf-module-aws-infra-pipeline
Terraform module for defining AWS CodePipeline for applying infrastructure from terraform code stored in GitHub-repository.

## Examples

- Pipeline _without_ manual approval
```
module "tf_infra_pipeline" {
  source                = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v1.0.0"
  github_repository_id  = "Nets-Platform-Enablement/sample-project"
  environment           = "dev"
  require_manual_approval = false
  tf_state_dynamodb_arn = data.aws_dynamodb_table.tf_state.arn
  tags                  = local.tags
}
```

- Pipeline with manual approval, failure and success reporting, custom variables file, custom branch-name
```
module "tf_infra_pipeline" {
  source                = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v1.0.0"
  github_repository_id  = "Nets-Platform-Enablement/sample-project"
  branch_name           = "staging"
  environment           = "preprod"
  require_manual_approval = true
  tf_state_dynamodb_arn = data.aws_dynamodb_table.tf_state.arn
  variables_file        = "environment/prod.tfvars"
  emails                = [ "first.last@nexigroup.com", "jane.doe@nexigroup.com" ]
  failure_notifications = true
  success_notifications = true
  managed_policies      = ["AmazonRDSFullAccess", "AWSCodeCommitPowerUser"]
  tags                  = local.tags
}
```
## Variables
| Name | Description | Type | Default | Notes |
|------|-------------|------|---------|-------|
| environment | Type of environment deploying to [test,dev,prod etc.] | string |  | Used in S3-bucket name so there might be collision |
| github_repository_id | ID of the terraform repository | string |  | `https://github.com/{this-part}.git` |
| branch_name | Name of the branch to deploy | string | `main` |  |
| tf_state_dynamodb_arn | ARN of the DynamoDB maintaining Terraform state | string |  |  |
| aws_region | AWS region to deploy pipeline to | string | `eu-central-1` |  |
| require_manual_approval | Whether or not a manual approval of changes is required before applying changes | bool | true |  |
| variables_file | File to provide terraform the variables with | string | "" | If not given, will automatically try to use `environments/{environment}.tfvars` |
| tags | Map of Tag-Value -pairs to be added to all resources | map |  | `{ Tag: "Value", Cool: true }` |
| managed_policies | List of AWS managed Policies to attach to pipeline | list(string) |  | example ['AmazonRDSFullAccess'] |
| emails | List of email-addresses receiving notifications on updates | list(string) | [] | All recipient will receive confirmation email from AWS |
| failure_notifications | Whether or not you want notifications on failed builds | bool | true |  |
| success_notifications | Whether or not you want notifications on succeeded builds | bool | false |  |
| checkov_skip_checks | List of CheckOV check you want to skip | string | "" |
| directory | directory for terraform hcl | string | "/" |
## Notes

- After initial deployment, the *CodeStar connection* needs to be [manually activated](https://eu-central-1.console.aws.amazon.com/codesuite/settings/connections), also ensure *AWS Connector for GitHub* has access to the repository you're deploying.
- The CodeBuild -project created by this module will by default get following AWS managed policices:
  - IAMFullAccess
  - AWSKeyManagementServicePowerUser
  - CloudWatchLogsFullAccess
  - CloudWatchEventsFullAccess
  - AWSCodePipeline_FullAccess
  - AWSCodeStarFullAccess
  - AWSCodeBuildAdminAccess
  - AWSCodeArtifactAdminAccess
  - AmazonSNSFullAccess
- If terraform should be able to manage any additional AWS services, you can provide AWS Policies using `managed_policies` variable.
- If the pipeline is trying to make changes to _itself_, things most likely will break. In such case, perform `terraform apply` manually.
