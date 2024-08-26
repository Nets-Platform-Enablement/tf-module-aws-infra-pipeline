output "sns_topic_arn" {
  description = "ARN of the SNS topic used by Infra Pipeline"
  value       = module.sns_topic.topic_arn
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = var.require_manual_approval ? aws_codepipeline.terraform[0].arn : aws_codepipeline.terraform_without_approval[0].arn
}

output "iam_role_arn" {
  description = "ARN for the IAM role used by CodeBuild"
  value       = aws_iam_role.codebuild.arn
}

output "iam_role_id" {
  description = "ID for the IAM role used by CodeBuild"
  value       = aws_iam_role.codebuild.id
}
