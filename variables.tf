# Mandatory
variable "environment" {
  type        = string
  description = "Type of environment deploying to [test,dev,prod]"
  sensitive   = false
}

variable "github_repository_id" {
  type        = string
  description = "GitHub Repository"
  sensitive   = false
}

variable "tf_state_dynamodb_arn" {
  type        = string
  description = "ARN of the DynamoDB maintaining Terraform state"
  sensitive   = false
}

# optional
variable "aws_region" {
  description = "AWS region to deploy resources to"
  default     = "eu-central-1"
  type        = string
  sensitive   = false
}

variable "require_manual_approval" {
  type        = bool
  description = "Whether or not a manual approval of changes is required before applying changes"
  default     = true
  sensitive   = false
}

variable "enable_checkov" {
  type        = bool
  description = "If TRUE, pipeline will run checkov against codebase"
  default     = false
  sensitive   = false
}

variable "require_checkov_pass" {
  type        = bool
  description = "If TRUE, failing checkov will fail the build"
  default     = false
  sensitive   = false
}

variable "branch_name" {
  type        = string
  description = "Name of the branch"
  default     = "main"
  sensitive   = false
}

variable "variables_file" {
  type        = string
  description = "File to provide terraform the variables with (./environments/{env}.tfvars)"
  default     = ""
  sensitive   = false
}

variable "terraform_version" {
  description = "The version of Terraform to use"
  type        = string
  default     = "1.9.3"
}

variable "tflint_version" {
  description = "The version of tflint to use"
  type        = string
  default     = "0.54.0"
}

variable "checkov_version" {
  description = "The version of checkov to use"
  type        = string
  default     = "latest"
}

variable "tfbackend_file" {
  type        = string
  description = "File to provide terraform the backend config with 'terraform init -backend-config {tfbackend_file}'"
  default     = ""
  sensitive   = false
}

variable "tags" {
  type        = map(any)
  description = "Map of Tag-Value -pairs to be added to all resources"
  default     = {}
  sensitive   = false
}

variable "managed_policies" {
  type        = set(string)
  description = "List of managed AWS Policies to attach to pipeline, for example ['AmazonRDSFullAccess']"
  default     = []
  sensitive   = false
}

variable "emails" {
  type        = set(string)
  description = "List of email-addresses receiving notifications on updates"
  default     = []
  sensitive   = false
}

variable "failure_notifications" {
  type        = string
  description = "Whether or not you want notifications on failed builds [ENABLED / DISABLED / ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS]"
  default     = "DISABLED"
  sensitive   = false
}

variable "success_notifications" {
  type        = string
  description = "Whether or not you want notifications on succeeded builds [ENABLED / DISABLED / ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS]"
  default     = "DISABLED"
  sensitive   = false
}

variable "directory" {
  type        = string
  description = "Run TFlint / Terraform in this directory"
  default     = ""
  sensitive   = false
}

variable "extra_build_artifacts" {
  type        = set(string)
  description = "Include these extra file from Plan step to Apply step"
  default     = ([""])
  sensitive   = false
}

variable "role_policy" {
  type        = object({
    Version   = optional(string, "2012-10-17")
    Statement = list(any)
  })
  description = "IAM policy document to be attached to CodeBuild role"
  default     = {Statement = []}
  sensitive   = false
}

variable "codebuild_image_id" {
  type        = string
  default     = "aws/codebuild/standard:7.0"
  description = "ID of the CodeBuild instance image"
}
