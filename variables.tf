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
  sensitive   = false
}

variable "require_manual_approval" {
  type        = bool
  description = "Whether or not a manual approval of changes is required before applying changes"
  default     = true
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

variable "tags" {
  type        = map(any)
  description = "Map of Tag-Value -pairs to be added to all resources"
  default     = {}
  sensitive   = false
}

variable "managed_policies" {
  type        = list(string)
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
  type        = bool
  description = "Whether or not you want notifications on failed builds"
  default     = true
  sensitive   = false
}

variable "success_notifications" {
  type        = bool
  description = "Whether or not you want notifications on succeeded builds"
  default     = false
  sensitive   = false
}

variable "checkov_skip_checks" {
  type        = string
  description = "Skip these CHECKOV checks"
  default     = "CKV_AWS_18,CKV_AWS_144,CKV_AWS_147,CKV_AWS_158,CKV_AWS_184,CKV_AWS_7,CKV_AWS_145,CKV_AWS_136,CKV_AWS_219,CKV_AWS_109,CKV_AWS_111,CKV2_AWS_38,CKV2_AWS_39"
  sensitive   = false
}
