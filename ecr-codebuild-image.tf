resource "aws_ecr_repository" "codebuild_image" {
  count                = local.manage_custom_codebuild_image ? 1 : 0
  name                 = lower("${local.name}-${var.environment}-codebuild-image")
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.codebuild.arn
  }

  image_scanning_configuration {
    scan_on_push = var.custom_codebuild_image_scan_on_push
  }
}

resource "aws_ecr_lifecycle_policy" "codebuild_image" {
  count      = local.manage_custom_codebuild_image ? 1 : 0
  repository = aws_ecr_repository.codebuild_image[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the latest 10 CodeBuild images"
        selection = {
          tagStatus   = "tagged"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged CodeBuild images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
