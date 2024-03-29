#IAM for CodePipeline

resource "aws_iam_role" "codepipeline" {
  name        = "CodepipelineRole-${local.name}"
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
  name = "CodepipelineRolePolicy-${local.name}"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:*"
          ],
          "Resource" : "*"
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
            module.sns_topic.sns_topic_arn
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:GenerateDataKey",
            "kms:Decrypt"
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
  name        = "CodebuildRole-${local.name}"
  description = "CodeBuild Service Role - Managed by Terraform"
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

  managed_policy_arns = [
    for n in keys(data.aws_iam_policy.managed) : data.aws_iam_policy.managed[n].arn
  ]
}

resource "aws_iam_role_policy" "codebuild" {
  name = "CodebuildRolePolicy-${local.name}"
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
          "Resource" : "*"
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
          "Resource" : ["${aws_iam_role.codepipeline.arn}", "${aws_iam_role.codebuild.arn}"]
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
      ]
    }
  )
}

resource "aws_sns_topic_policy" "terraform_updates" {
  arn    = module.sns_topic.sns_topic_arn
  policy = data.aws_iam_policy_document.events_publish_sns.json
}

data "aws_iam_policy_document" "events_publish_sns" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "s3.amazonaws.com"
      ]
    }

    resources = [module.sns_topic.sns_topic_arn]
  }
}
