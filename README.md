# tf-module-aws-infra-pipeline
Terraform module for defining AWS CodePipeline for applying infrastructure from terraform code stored in GitHub-repository.

## Examples

- Pipeline _without_ manual approval
```hcl
module "tf_infra_pipeline" {
  source                  = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v3.0.0"
  github_repository_id    = "Nets-Platform-Enablement/sample-project"
  environment             = "dev"
  require_manual_approval = false
  tf_state_dynamodb_arn   = data.aws_dynamodb_table.tf_state.arn # Optional: only needed if using DynamoDB for state locking
  variables_file          = "environment/dev.tfvars"
  tags                    = local.tags
}
data "aws_dynamodb_table" "tf_state" {
  name = "terraform-state-lock-sample-project"
}
```

- Pipeline with manual approval, failure and success reporting, custom variables file, .tfbackend-file, custom branch-name
```hcl
module "tf_infra_pipeline" {
  source                        = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v3.0.0"
  name                          = "example-pipeline"
  github_repository_id          = "Nets-Platform-Enablement/sample-project"
  branch_name                   = "staging"
  environment                   = "preprod"
  require_manual_approval       = true
  pipeline_design               = "optimized"
  enable_checkov                = true
  require_checkov_pass          = true
  enable_custom_codebuild_image = true
  custom_codebuild_image_uri    = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/codebuild-terraform:tf-1-9-8-tflint-v0-53-0-checkov-3-2-281"
  terraform_version             = "1.9.8"
  tflint_version                = "0.53.0"
  checkov_version               = "3.2.281"
  tf_state_dynamodb_arn         = data.aws_dynamodb_table.tf_state.arn # Optional: only needed if using DynamoDB for state locking
  variables_file                = "environment/prod.tfvars"
  tfbackend_file                = "environment/prod.s3.tfbackend"
  emails                        = ["first.last@nexigroup.com", "jane.doe@nexigroup.com"]
  failure_notifications         = "ENABLED"
  success_notifications         = "ENABLED"
  logs_retention_time           = 30
  managed_policies              = ["AmazonRDSFullAccess", "AWSCodeCommitPowerUser"]
  role_policy = {
    Statement = [
      {
        Sid    = "EC2FullAccess"
        Effect = "Allow"
        Action = [
          "ec2:*",
        ]
        Resource = "*"
      },
    ]
  }
  tags      = local.tags
  directory = ""
}
data "aws_dynamodb_table" "tf_state" {
  name = "terraform-state-lock-sample-project"
}

```
## Requirements

- Terraform `>= 1.9.0`
- AWS provider `>= 5.72.0`
- HTTP provider `>= 3.5.0`
- Null provider `>= 3.2.4`

Terraform 1.9 or newer is required because the module validates `custom_codebuild_image_uri` using an input variable validation rule that references other input variables.

## Variables
| Name | Description | Type | Default | Notes |
|------|-------------|------|---------|-------|
| environment | Type of environment deploying to [test,dev,prod etc.] | string |  | Used in S3-bucket name so there might be collision |
| name | Optional name for the pipeline, if not given, name is derived from the github repository name | string | "" | Alpha-numeric, dash (-) and underscore(_) allowed. Renaming pipeline does not work, deploy new instance of the module instead |
| github_repository_id | ID of the terraform repository | string |  | `https://github.com/{this-part}.git` |
| branch_name | Name of the branch to deploy | string | `main` |  |
| tf_state_dynamodb_arn | ARN of the DynamoDB maintaining Terraform state (optional) | string | "" | Leave empty if not using DynamoDB for state locking |
| aws_region | AWS region to deploy pipeline to | string | `eu-central-1` |  |
| require_manual_approval | Whether or not a manual approval of changes is required before applying changes | bool | true |  |
| pipeline_design | Pipeline design to use | string | `legacy` | `legacy` preserves the v2 pipeline shape for in-place upgrades. `optimized` enables the v3 optimized pipeline design |
| variables_file | File to provide terraform the variables with | string | "" | If not given, will automatically try to use `environments/{environment}.tfvars` |
| tfbackend_file | File to provide terraform the backend config with | string | "" | Naming convension: {environment}.s3.tfbackend, see [HashiCorp documentation](https://developer.hashicorp.com/terraform/language/settings/backends/configuration#using-a-backend-block) |
| terraform_version | The version of Terraform to use | string | "latest" | Either semantic version number or "latest" |
| tflint_version | The version of tflint to use | string | "latest" | Either semantic version number or "latest" |
| checkov_version | The version of checkov to use | string | "latest" | Either semantic version number or "latest" |
| codebuild_image_id | ID of the CodeBuild instance image | string | "aws/codebuild/standard:7.0" | [CodeBuild documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/ec2-compute-images.html) |
| enable_custom_codebuild_image | Whether to use a custom CodeBuild image in optimized pipeline mode | bool | false | Requires `custom_codebuild_image_uri` to point to an externally managed image |
| custom_codebuild_image_uri | Existing custom CodeBuild image URI to use in optimized pipeline mode | string | "" | Required when `enable_custom_codebuild_image = true` |
| vpc_id | VPC ID where CodeBuild projects will run (optional) | string | "" | If provided, CodeBuild instances will run inside the VPC in private networks |
| subnet_ids | List of subnet IDs for CodeBuild projects (optional) | list(string) | [] | Use private subnets for security. Required if vpc_id is provided |
| security_group_ids | List of security group IDs for CodeBuild projects (optional) | list(string) | [] | If not provided, a default security group with egress-only rules will be created |
| tags | Map of Tag-Value -pairs to be added to all resources | map(any) | {} | `{ Tag: "Value", Cool: true }` |
| managed_policies | Set of AWS managed Policies to attach to pipeline | set(string) | [] | example `["AmazonRDSFullAccess"]` |
| role_policy | IAM policy document to attach to the CodeBuild role | object | { Statement = [] } | Similar to [iam_role_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy); the module formats the value into JSON |
| emails | Set of email-addresses receiving notifications on updates | set(string) | [] | All recipients will receive confirmation email from AWS |
| failure_notifications | Whether or not you want notifications on failed builds | string | "DISABLED" | [ENABLED / DISABLED / ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS] |
| success_notifications | Whether or not you want notifications on succeeded builds | string | "DISABLED" | [ENABLED / DISABLED / ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS] |
| directory | directory for terraform hcl | string | "" | use "<folder>" if your code is in sub folder |
| extra_build_artifacts | filenames to be included for codepipeline apply step | set(string) | ([""]) |
| enable_checkov | If checkov should be ran | boolean | false | Without `require_checkov_pass = true`, this will only log the findings | 
| require_checkov_pass | Should failed checkov check prevent the changes from being applied | boolean | false | Requires `enable_checkov = true` to be effective | 
| logs_retention_time | Time to retain the logs in days, allowed values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365 and 0 | integer | 30 | 0 = never expire | 

## State Locking Configuration

**Recommended**: Instead of using DynamoDB for state locking, use the native S3 state locking feature by adding `use_lockfile = true` to your `.tfbackend` file:

```hcl
bucket         = "your-terraform-state-bucket"
key            = "path/to/your/terraform.tfstate"
region         = "eu-central-1"
use_lockfile   = true
```

This approach:
- Eliminates the need for a separate DynamoDB table
- Reduces infrastructure complexity and costs
- Provides the same locking functionality using S3's native capabilities
- No longer requires the `tf_state_dynamodb_arn` variable

If you're currently using DynamoDB for state locking, you can migrate by:
1. Adding `use_lockfile = true` to your `.tfbackend` file
2. Removing or leaving empty the `tf_state_dynamodb_arn` variable in your module configuration
3. The DynamoDB table can be removed after successful migration

## VPC Configuration (Optional)

You can optionally run CodeBuild instances inside a VPC in private networks for enhanced security. This is useful when your Terraform code needs to access resources in a private network or when you want to restrict outbound internet access.

To enable VPC configuration, provide the VPC ID and subnet IDs:

```hcl
module "tf_infra_pipeline" {
  source = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v3.0.0"
  
  # ... other required variables ...
  
  # VPC Configuration (minimum required)
  vpc_id     = "vpc-1234567890abcdef0"
  subnet_ids = ["subnet-12345678", "subnet-87654321"]  # Use private subnets
  
  # Optional: Provide your own security groups
  # security_group_ids = ["sg-12345678"]
}
```

**Security Group Behavior:**
- If you don't provide `security_group_ids`, the module will automatically create a default security group with:
  - **Egress (outbound)**: Allow all traffic (required for downloading packages, accessing AWS APIs, etc.)
  - **Ingress (inbound)**: No inbound rules (CodeBuild doesn't need incoming connections)
- If you provide `security_group_ids`, your security groups will be used instead

**Important considerations:**
- Use **private subnets** for security best practices
- Ensure your subnets have either:
  - NAT Gateway configured for internet access (required for downloading Terraform, tflint, etc.)
  - VPC endpoints for AWS services (S3, ECR, CloudWatch Logs, etc.)
- If using custom security groups, ensure they allow outbound traffic to required services
- The CodeBuild IAM role automatically receives the necessary EC2 network interface permissions when VPC is configured

If you don't provide VPC configuration, CodeBuild instances will run in AWS-managed infrastructure with public internet access (default behavior).

## v3 Pipeline Design and In-Place Upgrade

Version 3 introduces an optimized pipeline design, but keeps the legacy v2 pipeline shape as the default. This lets existing users update the module version in place first and opt into the new design later.

Recommended upgrade path:

1. Update the module source/ref to v3 and leave `pipeline_design` unset, or set `pipeline_design = "legacy"` explicitly.
2. Run `terraform plan` and confirm the existing pipeline remains on the legacy design.
3. In a separate change, set `pipeline_design = "optimized"` after reviewing the planned resource changes.

Legacy mode preserves the current behavior:
- Separate CodeBuild projects for `tflint`, optional `checkov`, `terraform plan`, and `terraform apply`
- Existing S3 package download flow for Terraform and tflint
- Existing manual approval and auto-approve behavior

Optimized mode changes the pipeline shape:
- Runs `terraform init` once before approval
- Runs `terraform validate`, `tflint`, and optional `checkov` in a consolidated `validate-plan` CodeBuild project
- Produces both `thePlan.tfp` and a readable `plan.txt` artifact
- Keeps manual approval tied to the saved plan artifact
- Applies the exact saved plan artifact in the deploy stage

To enable optimized mode with a custom CodeBuild image:

```hcl
module "tf_infra_pipeline" {
  source = "git::https://github.com/Nets-Platform-Enablement/tf-module-aws-infra-pipeline?ref=v3.0.0"

  # ... other required variables ...

  pipeline_design               = "optimized"
  enable_checkov                = true
  require_checkov_pass          = true
  enable_custom_codebuild_image = true
  custom_codebuild_image_uri    = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/codebuild-terraform:tf-1-9-8-tflint-v0-53-0-checkov-3-2-281"
  terraform_version             = "1.9.8"
  tflint_version                = "0.53.0"
  checkov_version               = "3.2.281"
}
```

When `enable_custom_codebuild_image = true`, `custom_codebuild_image_uri` must point to an image that is built and published outside this module. This avoids the pipeline having to build its own runtime image before it can run validate/plan/apply.

```hcl
pipeline_design               = "optimized"
enable_custom_codebuild_image = true
custom_codebuild_image_uri    = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/codebuild-terraform:tf-1-9-8-tflint-v0-53-0-checkov-3-2-281"
```

Rollback options:
- Set `pipeline_design = "legacy"` to return to the legacy pipeline shape
- Keep `pipeline_design = "optimized"` and pin `custom_codebuild_image_uri` to a previous known-good image tag

## Notes

- Pipeline cannot do renaming (or adding `name`) to itself. Instead create a new instance of the module, apply changes and then remove the old instance. Also note the CodeStar connection note below.
- After initial deployment, the *CodeStar connection* needs to be [manually activated](https://eu-central-1.console.aws.amazon.com/codesuite/settings/connections), also ensure *AWS Connector for GitHub* has access to the repository you're deploying.
- The CodeBuild -project created by this module will by default get following AWS managed policies:
  - IAMFullAccess
  - AWSCodePipeline_FullAccess
  - AWSCodeStarFullAccess
  - AWSCodeBuildAdminAccess
- If terraform should be able to manage any additional AWS services, you can provide AWS Policies using `managed_policies` variable.
- For defining more granular permissions, use `role_policy` variable.
- If the pipeline is trying to make changes to _itself_, things most likely will break. In such case, perform `terraform apply` manually.

## Outputs

| Name                | Description                                              |
|---------------------|----------------------------------------------------------|
| name                | Name of the pipeline                                     |
| sns_topic_arn       | ARN of the SNS topic used by Infra Pipeline              |
| codepipeline_arn    | ARN of the CodePipeline                                  |
| iam_role_arn        | ARN for the IAM role used by CodeBuild                   |
| iam_role_id         | ID for the IAM role used by CodeBuild                    |
| artifact_bucket_id  | ID of the bucket terraform plans are stored in           |
| codebuild_role_arn  | ARN for the CodeBuild IAM role                           |
| codebuild_image_repository_url | Deprecated. Always `null`; the module no longer creates a managed custom CodeBuild image repository |
| codebuild_runtime_image | CodeBuild runtime image selected by the module |

## Releases

### v.3.0.0 Optimized pipeline design
- Breaking change: Terraform `>= 1.9.0` is required for cross-variable input validation
- New setting: `pipeline_design`, defaulting to `legacy` for in-place upgrades from v2
- New optimized pipeline design with consolidated validate/lint/security/plan CodeBuild project
- New optional custom CodeBuild image support for Terraform, tflint and Checkov
- Custom CodeBuild images must be built outside this module and provided with `custom_codebuild_image_uri`
- Optimized mode keeps approval tied to the saved Terraform plan artifact
- Legacy mode preserves the existing v2 pipeline shape and package download behavior

### v.2.2.2
- New output: `codebuild_role_arn` (ARN for the CodeBuild IAM role)
- Documentation: All module outputs are now described in the README

### v.2.2.1
- Prevent accidental destruction of `ams_kms_key`
- Added filter prefix to `aws_s3_bucket_lifecycle_configuration`
- Minor improvements to package download logic
- Code formatting and cleanup
- This version supports also Windows as running environment.

### v.2.2.0 Optional Checkov checks
- *Breaking change*: This version does not support Windows as running environment.
- Checkov checks can be enabled/disabled and be done with soft- or hard fail mode
  - New settings: `enable_checkov` and `require_checkov_pass` to stop the pipeline on checkov errors
- terraform/tflint packages are stored in S3 bucket
- Possibility to define version of tflint and checkov (default: 'latest')
- Possibility to give the module a `name`
- Terraform version requirement lowered to 1.3.0
- fix: Deprecation fix for aws_iam_role.managed_policy_arns
- fix: CodeBuild project log to a single CloudWatch Group `codebuild/{name}`
  - New setting `logs_retention_time`

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
