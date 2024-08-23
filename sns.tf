#Creating SNS topic
module "sns_topic" {
  source  = "git::https://github.com/terraform-aws-modules/terraform-aws-sns.git?ref=6404f81"
  #version = "6.1.0"

  name              = "${local.name}-${var.environment}-updates"
  kms_master_key_id = aws_kms_key.sns_topic_encryption.id

  tags = merge(local.tags, { Secure = "true" })
}

#Key to encrypt sns topic messages
resource "aws_kms_key" "sns_topic_encryption" {
  description             = "Key for encrypting s3 sns topic"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sns-topic-policy.json
  tags                    = local.tags
}
resource "aws_kms_alias" "sns_topic_s3_encryption" {
  name          = "alias/${local.name}_sns_topic_encrypt"
  target_key_id = aws_kms_key.sns_topic_encryption.key_id
}
data "aws_iam_policy_document" "sns-topic-policy" {
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        aws_iam_role.codebuild.arn
      ]
    }
  }
  statement {
    sid    = "Allow CloudWatch for CMK"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "cloudwatch.amazonaws.com",
        "events.amazonaws.com",
        "s3.amazonaws.com"
      ]
    }

    actions   = ["kms:Decrypt*", "kms:GenerateDataKey*"]
    resources = ["*"]
  }
  #checkov:skip=CKV_AWS_111; permissions given to single key(s)
  #checkov:skip=CKV_AWS_109; CodeBuildRole needs editing permissions
  #checkov:skip=CKV_AWS_356; "*" in this context is "this key"
}

#Create subcriptions to sns topic
resource "aws_sns_topic_subscription" "send_email" {
  topic_arn = module.sns_topic.topic_arn
  protocol  = "email"
  for_each  = var.emails
  endpoint  = each.value
}

resource "aws_cloudwatch_event_rule" "failed_builds" {
  name        = "${local.name}-${var.environment}-build-failure"
  description = "Managed by Terraform"
  state       = var.failure_notifications
  event_pattern = jsonencode({
    "source" : [
      "aws.codebuild"
    ],
    "detail-type" : [
      "CodeBuild Build State Change"
    ],
    "detail" : {
      "build-status" : [
        "FAILED",
        "STOPPED",
      ],
      "project-name" : [
        aws_codebuild_project.tflint.name,
        aws_codebuild_project.tf_plan.name,
        aws_codebuild_project.tf_apply.name,
      ]
    }
  })
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "sns_failed_builds" {
  rule      = aws_cloudwatch_event_rule.failed_builds.name
  target_id = "SendToSNS"
  arn       = module.sns_topic.topic_arn
  input_transformer {
    input_paths = {
      project = "$.detail.project-name",
      status  = "$.detail.build-status",
      link    = "$.detail.additional-information.logs.deep-link",
      account = "$.account",
    }
    input_template = <<EOF
{
  "Project": "${local.name}", 
  "environment": "${var.environment}", 
  "account": <account>,
  "step": <project>,
  "status": <status>,
  "logs": <link>
}  
EOF
  }
}

resource "aws_cloudwatch_event_rule" "succes_builds" {
  name        = "${local.name}-${var.environment}-build-succeeded"
  description = "Managed by Terraform"
  state       = var.success_notifications
  event_pattern = jsonencode({
    "source" : [
      "aws.codebuild"
    ],
    "detail-type" : [
      "CodeBuild Build State Change"
    ],
    "detail" : {
      "build-status" : [
        "SUCCEEDED",
      ],
      "project-name" : [
        aws_codebuild_project.tf_apply.name,
      ]
    }
  })
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "sns_success_builds" {
  rule      = aws_cloudwatch_event_rule.succes_builds.name
  target_id = "SendToSNS"
  arn       = module.sns_topic.topic_arn
  input_transformer {
    input_paths = {
      project = "$.detail.project-name",
      status  = "$.detail.build-status",
      link    = "$.detail.additional-information.logs.deep-link",
      account = "$.account",
    }
    input_template = <<EOF
{
  "Project": "${local.name}", 
  "environment": "${var.environment}", 
  "account": <account>,
  "step": <project>,
  "status": <status>,
  "logs": <link>
}  
EOF
  }
}
