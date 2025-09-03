#IAM for CodePipeline

resource "aws_iam_role" "codepipeline" {
  name_prefix = substr("CodepipelineRole-${local.name}", 0, 38)
  description = "CodePipeline Service Role for ${local.name} - Managed by Terraform"
  tags        = local.tags

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "codepipeline.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy" "codepipeline" {
  role = aws_iam_role.codepipeline.id
  name = substr("CodepipelineRolePolicy-${local.name}", 0, 64)

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:*"
          ],
          "Resource" : [
            aws_s3_bucket.codepipeline_artifacts_store.arn,
            "${aws_s3_bucket.codepipeline_artifacts_store.arn}/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : "iam:PassRole",
          "Resource" : aws_iam_role.codebuild.arn
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "codecommit:BatchGet*",
            "codecommit:BatchDescribe*",
            "codecommit:Describe*",
            "codecommit:Get*",
            "codecommit:List*",
            "codecommit:GitPull",
            "codecommit:UploadArchive",
            "codecommit:GetBranch",
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "sns:Publish"
          ],
          "Resource" : [
            module.sns_topic.topic_arn
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:GenerateDataKey",
            "kms:Decrypt",
            "kms:ListAliases"
          ],
          "Resource" : [
            "*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "codebuild:StartBuild",
            "codebuild:StopBuild",
            "codebuild:BatchGetBuilds"
          ],
          "Resource" : [
            aws_codebuild_project.tflint.arn,
            aws_codebuild_project.checkov.arn,
            aws_codebuild_project.tf_plan.arn,
            aws_codebuild_project.tf_apply.arn
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : "codestar-connections:UseConnection",
          "Resource" : "${aws_codestarconnections_connection.this.arn}"
        }
      ]
    }
  )
}

#IAM for CodeBuild

resource "aws_iam_role" "codebuild" {
  name_prefix = substr("CodebuildRole-${local.name}", 0, 38)
  description = "CodeBuild Service Role for ${local.name} - Managed by Terraform"
  tags        = local.tags

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "codebuild.amazonaws.com"

          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachments_exclusive" "codebuild" {
  role_name = aws_iam_role.codebuild.name
  policy_arns = [
    for n in keys(data.aws_iam_policy.managed_default) : data.aws_iam_policy.managed_default[n].arn
  ]
}

resource "aws_iam_role_policy" "aws_managed" {
  for_each = tomap(data.aws_iam_policy.managed)
  name     = "CodebuildRolePolicy-${each.key}"
  role     = aws_iam_role.codebuild.id

  policy = each.value.policy
}

resource "aws_iam_role_policy" "codebuild" {
  name = substr("CodebuildRolePolicy-${local.name}", 0, 64)
  role = aws_iam_role.codebuild.id

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:*"
          ],
          "Resource" : [
            aws_s3_bucket.codepipeline_artifacts_store.arn,
            "${aws_s3_bucket.codepipeline_artifacts_store.arn}/*",
            "arn:aws:s3:::*" # terraform state bucket is not known, but CodeBuild needs write access
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:*"
          ],
          "Resource" : var.tf_state_dynamodb_arn
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListRolePolicies",
            "iam:ListAttachedRolePolicies"
          ],
          "Resource" : [aws_iam_role.codepipeline.arn, aws_iam_role.codebuild.arn]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "iam:ListPolicies",
            "iam:GetPolicy",
            "iam:GetPolicyVersion",
          ],
          "Resource" : ["*"]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:ListAliases"
          ],
          "Resource" : [
            "*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:*"
          ],
          "Resource" : [
            aws_kms_key.codeartifact_key.arn,
            aws_kms_key.sns_topic_encryption.arn,
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : "sts:GetServiceBearerToken",
          "Resource" : "*",
          "Condition" : {
            "StringEquals" : {
              "sts:AWSServiceName" : "codeartifact.amazonaws.com"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : "iam:PassRole",
          "Resource" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:GetLogEvents",
            "logs:PutLogEvents",
          ],
          "Resource" : ["arn:aws:logs:*:*:log-group:/aws/codebuild/*:*"]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogStreams",
            "logs:PutRetentionPolicy",
            "logs:CreateLogGroup"
          ],
          "Resource" : ["arn:aws:logs:*:*:log-group:/aws/codebuild/*:*"]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:DescribeVpcAttribute",
          ],
          "Resource" : ["arn:aws:ec2:*:*:vpc/*"]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "SNS:*",
          ],
          "Resource" : [module.sns_topic.topic_arn]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "events:*",
          ],
          "Resource" : [
            aws_cloudwatch_event_rule.failed_builds.arn,
            aws_cloudwatch_event_rule.succes_builds.arn
          ]
        },
      ]
    }
  )
}

# User defined IAM policy for CodeBuild role
resource "aws_iam_role_policy" "codebuild_additionals" {
  count = length(var.role_policy.Statement) > 0 ? 1 : 0 # Do not add if role_policy is not given
  name  = "CodebuildRolePolicy-${local.name}-additional"
  role  = aws_iam_role.codebuild.id

  policy = jsonencode(
    var.role_policy
  )
}
