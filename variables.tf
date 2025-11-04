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
  description = "ARN of the DynamoDB maintaining Terraform state (optional)"
  default     = ""
  sensitive   = false
}

# optional
variable "aws_region" {
  description = "AWS region to deploy resources to"
  default     = "eu-central-1"
  type        = string
  sensitive   = false
}

variable "name" {
  description = "Name of the pipeline, used naming resources it has"
  default     = ""
  type        = string
  sensitive   = false
  validation {
    # regex(...) fails if it cannot find a match
    condition     = length(var.name) == 0 || can(regex("^[0-9A-Za-z_-]+$", var.name))
    error_message = "For the name value only a-Z, 0-9, dash and underscore are allowed."
  }
  validation {
    condition     = length(var.name) == 0 || length(var.name) <= 38
    error_message = "The name value must be 38 characters or less."
  }
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
  default     = "latest"
}

variable "tflint_version" {
  description = "The version of tflint to use, either semantic version number or 'latest'"
  type        = string
  default     = "latest"
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

variable "logs_retention_time" {
  type        = number
  default     = 30
  description = "Number of days to keep the logs, possible values 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365 and 0 (never expire)"
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
  type = object({
    Version   = optional(string, "2012-10-17")
    Statement = list(any)
  })
  description = "IAM policy document to be attached to CodeBuild role"
  default     = { Statement = [] }
  sensitive   = false
}

variable "codebuild_image_id" {
  type        = string
  default     = "aws/codebuild/standard:7.0"
  description = "ID of the CodeBuild instance image"
}

variable "codebuild_compute_type" {
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
  description = "CodeBuild compute type. Options: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_GENERAL1_2XLARGE"
  validation {
    condition     = contains(["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE", "BUILD_GENERAL1_2XLARGE"], var.codebuild_compute_type)
    error_message = "Compute type must be one of: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_GENERAL1_2XLARGE"
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where CodeBuild projects will run (optional). If provided, CodeBuild will run inside the VPC"
  default     = ""
  sensitive   = false
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for CodeBuild projects (optional). Use private subnets for security. Required if vpc_id is provided"
  default     = []
  sensitive   = false
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs for CodeBuild projects (optional). If not provided and vpc_id is set, a default security group with egress-only rules will be created"
  default     = []
  sensitive   = false
}
