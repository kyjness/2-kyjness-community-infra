# GitHub Actions → AWS: OIDC (AssumeRoleWithWebIdentity). AK/SK 없이 FE S3 배포·CloudFront 무효화.
# 순환 참조 없음: 본 파일은 frontend S3·CloudFront 리소스를 읽기만 함.

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = local.github_oidc_url

  client_id_list = ["sts.amazonaws.com"]

  # token.actions.githubusercontent.com TLS 체인 기준(로테이션 시 AWS/GitHub 문서 확인)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_policy_document" "github_actions_fe_assume" {
  statement {
    sid     = "GithubActionsFeAssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_fe_oidc_subject]
    }
  }
}

data "aws_iam_policy_document" "github_actions_fe_deploy" {
  statement {
    sid    = "S3FrontendList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.frontend.arn]
  }

  statement {
    sid    = "S3FrontendObjectsWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
  }

  statement {
    sid    = "CloudFrontInvalidateCache"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
    ]
    resources = [aws_cloudfront_distribution.frontend.arn]
  }
}

resource "aws_iam_role" "fe_github_actions" {
  name               = "${var.project_name}-fe-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_fe_assume.json

  tags = {
    Name = "${var.project_name}-fe-github-actions-role"
  }
}

resource "aws_iam_role_policy" "fe_github_actions_deploy" {
  name   = "${var.project_name}-fe-github-actions-deploy"
  role   = aws_iam_role.fe_github_actions.id
  policy = data.aws_iam_policy_document.github_actions_fe_deploy.json
}

# -----------------------------------------------------------------------------
# BE GitHub Actions → AWS: OIDC로 ECR push + ECS 무중단 배포 (UpdateService).
# 이전에는 Jenkins EC2 인스턴스 프로파일이 담당하던 CD 역할을, 정적 키 없는 OIDC로 일원화.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_be_assume" {
  statement {
    sid     = "GithubActionsBeAssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_be_oidc_subject]
    }
  }
}

# 최소 권한: 지정 ECR 저장소 + 지정 ECS 서비스만 (GetAuthorizationToken은 AWS 제약으로 Resource *)
data "aws_iam_policy_document" "github_actions_be_deploy" {
  statement {
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushPullRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.be.arn]
  }

  statement {
    sid       = "EcsDeployService"
    effect    = "Allow"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = ["arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.main.name}/${aws_ecs_service.be.name}"]
  }
}

resource "aws_iam_role" "be_github_actions" {
  name               = "${var.project_name}-be-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_be_assume.json

  tags = {
    Name = "${var.project_name}-be-github-actions-role"
  }
}

resource "aws_iam_role_policy" "be_github_actions_deploy" {
  name   = "${var.project_name}-be-github-actions-deploy"
  role   = aws_iam_role.be_github_actions.id
  policy = data.aws_iam_policy_document.github_actions_be_deploy.json
}
