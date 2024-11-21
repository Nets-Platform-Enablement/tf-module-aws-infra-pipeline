# tf-module-aws-infra-pipeline
Terraform module for defining AWS CodePipeline for applying infrastructure from terraform code stored in GitHub-repository.

## Examples

- Pipeline _without_ manual approval
```
module "tf_infra_pipeline" {
  source                = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v2.1.0"
  github_repository_id  = "Nets-Platform-Enablement/sample-project"
  environment           = "dev"
  require_manual_approval = false
  tf_state_dynamodb_arn = data.aws_dynamodb_table.tf_state.arn
  variables_file        = "environment/dev.tfvars"
  tags                  = local.tags
}
data "aws_dynamodb_table" "tf_state" {
  name = "terraform-state-lock-sample-project"
}
```

- Pipeline with manual approval, failure and success reporting, custom variables file, .tfbackend-file, custom branch-name
```
module "tf_infra_pipeline" {
  source                = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v.2.2.0"
  name                  = "example-pipeline"
  github_repository_id  = "Nets-Platform-Enablement/sample-project"
  branch_name           = "staging"
  environment           = "preprod"
  require_manual_approval = true
  enable_checkov        = true
  require_checkov_pass  = true
  terraform_version     = "1.9.8"
  tflint_version        = "0.53.0"
  checkov_version       = "3.2.281"
  tf_state_dynamodb_arn = data.aws_dynamodb_table.tf_state.arn
  variables_file        = "environment/prod.tfvars"
  codebuild_image_id    = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
  tfbackend_file        = "environment/prod.s3.tfbackend"
  emails                = [ "first.last@nexigroup.com", "jane.doe@nexigroup.com" ]
  failure_notifications = "ENABLED"
  success_notifications = "ENABLED"
  managed_policies      = ["AmazonRDSFullAccess", "AWSCodeCommitPowerUser"]
  role_policy           = {
    Statement = [
      {
        Sid      = "EC2FullAccess"
        Effect   = "Allow"
        Action   = [
          "ec2:*",
        ]
        Resource = "*"
      },
    ]
  }
  tags                  = local.tags
  directory             = ""
}
data "aws_dynamodb_table" "tf_state" {
  name = "terraform-state-lock-sample-project"
}

```
## Variables
| Name | Description | Type | Default | Notes |
|------|-------------|------|---------|-------|
| environment | Type of environment deploying to [test,dev,prod etc.] | string |  | Used in S3-bucket name so there might be collision |
| name | Optional name for the pipeline, if not given, name is derived from the github repository name | string | "" | Alpha-numeric, dash (-) and underscore(_) allowed |
| github_repository_id | ID of the terraform repository | string |  | `https://github.com/{this-part}.git` |
| branch_name | Name of the branch to deploy | string | `main` |  |
| tf_state_dynamodb_arn | ARN of the DynamoDB maintaining Terraform state | string |  |  |
| aws_region | AWS region to deploy pipeline to | string | `eu-central-1` |  |
| require_manual_approval | Whether or not a manual approval of changes is required before applying changes | bool | true |  |
| variables_file | File to provide terraform the variables with | string | "" | If not given, will automatically try to use `environments/{environment}.tfvars` |
| tfbackend_file | File to provide terraform the backend config with | string | "" | Naming convension: {environment}.s3.tfbackend, see [HashiCorp documentation](https://developer.hashicorp.com/terraform/language/settings/backends/configuration#using-a-backend-block) |
| terraform_version | The version of Terraform to use | string | "latest" | Either semantic version number or "latest" |
| tflint_version | The version of tflint to use | string | "latest" | Either semantic version number or "latest" |
| checkov_version | The version of checkov to use | string | "latest" | Either semantic version number or "latest" |
| codebuild_image_id | ID of the CodeBuild instance image | string | "aws/codebuild/standard:7.0" | [CodeBuild documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/ec2-compute-images.html) |
| tags | Map of Tag-Value -pairs to be added to all resources | map |  | `{ Tag: "Value", Cool: true }` |
| managed_policies | List of AWS managed Policies to attach to pipeline | list(string) |  | example ['AmazonRDSFullAccess'] |
| role_policy | A map describing IAM Role Policy, similar to [iam_role_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy). Module will format the value into json-string. | object({}) | {Statement = []} |  |
| emails | List of email-addresses receiving notifications on updates | list(string) | [] | All recipient will receive confirmation email from AWS |
| failure_notifications | Whether or not you want notifications on failed builds | string | "DISABLED" | [ENABLED / DISABLED / ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS] |
| success_notifications | Whether or not you want notifications on succeeded builds | string | "DISABLED" | [ENABLED / DISABLED / ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS] |
| directory | directory for terraform hcl | string | "" | use "<folder>" if your code is in sub folder |
| extra_build_artifacts | filenames to be included for codepipeline apply step | set(string) | ([""]) |
| enable_checkov | If checkov should be ran | boolean | false | Without `require_checkov_pass = true`, this will only log the findings | 
| require_checkov_pass | Should failed checkov check prevent the changes from being applied | boolean | false | Requires `enable_checkov = true` to be effective | 
## Notes

- After initial deployment, the *CodeStar connection* needs to be [manually activated](https://eu-central-1.console.aws.amazon.com/codesuite/settings/connections), also ensure *AWS Connector for GitHub* has access to the repository you're deploying.
- The CodeBuild -project created by this module will by default get following AWS managed policices:
  - IAMFullAccess
  - AWSCodePipeline_FullAccess
  - AWSCodeStarFullAccess
  - AWSCodeBuildAdminAccess
- If terraform should be able to manage any additional AWS services, you can provide AWS Policies using `managed_policies` variable.
- For defining more granular permissions, use `role_policy` variable.
- If the pipeline is trying to make changes to _itself_, things most likely will break. In such case, perform `terraform apply` manually.

## Releases

### v.2.2.0 Optional Checkov checks
- Checkov checks can be enabled/disabled and be done with soft- or hard fail mode
  - New settings: `enable_checkov` and `require_checkov_pass` to stop the pipeline on checkov errors
- terraform/tflint packages are stored in S3 bucket
- Possibility to define version of tflint and checkov (default: 'latest')
- fix: Deprecation fix for aws_iam_role.managed_policy_arns


### v.2.1.0 Customizable build image
- New setting `codebuild_image_id`, by default "aws/codebuild/standard:7.0", more options at [CodeBuild documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/ec2-compute-images.html)
- New output: `artifact_bucket_id` ID of the bucket terraform plans are stored in
- Fix: Deployment fails due to S3 Notification Configuration issue. Removed S3 notifications.
- Fix: Name collision when creating multiple instances of the module

### v.2.0.0 Permissions overhaul

- *Breaking change*: Removed multiple AWS managed role policies from module in favor of more granual permission definition. Adding following policies to `managed_policies` will result in same permissions as in *v1.3.0* or earlier.
  - Removed policies:
    - AWSKeyManagementServicePowerUser
    - CloudWatchLogsFullAccess
    - CloudWatchEventsFullAccess
    - AWSCodeArtifactAdminAccess
    - AmazonSNSFullAccess
- AWS Managed policies `managed_policies` now support more than 10 policies.
- New setting: `role_policy` for defining more detailed permissions than `managed_policies` can do.
- New setting `terraform_version`

### v.1.3.0 Support for custom .tfbackend files
- New setting: `tfbackend_file`, File to provide terraform the backend config with

### Earlier

Please refer to [Releases GitHub-page](https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline/releases)
