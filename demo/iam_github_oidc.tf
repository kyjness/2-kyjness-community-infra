# GitHub Actions → AWS: OIDC(AssumeRoleWithWebIdentity). 프론트 배포에 장기 키를 두지 않는다.
# 백엔드 배포는 Lightsail에 롤을 붙일 수 없어 SSH로 하며, 그래서 여기에는 FE 롤만 있다.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # token.actions.githubusercontent.com TLS 체인 기준(로테이션 시 AWS/GitHub 문서 확인)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_policy_document" "fe_assume" {
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

    # 이 조건이 빠지면 GitHub의 아무 저장소나 이 롤을 맡을 수 있다.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_fe_oidc_subject]
    }
  }
}

data "aws_iam_policy_document" "fe_deploy" {
  statement {
    sid       = "S3FrontendList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"] # aws s3 sync --delete 가 기존 객체 목록을 읽는다
    resources = [aws_s3_bucket.frontend.arn]
  }

  statement {
    sid       = "S3FrontendObjectsWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
  }

  statement {
    sid       = "CloudFrontInvalidateCache"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role" "fe_github_actions" {
  name               = "${var.project_name}-fe-github-actions"
  assume_role_policy = data.aws_iam_policy_document.fe_assume.json
}

resource "aws_iam_role_policy" "fe_github_actions" {
  name   = "${var.project_name}-fe-deploy"
  role   = aws_iam_role.fe_github_actions.id
  policy = data.aws_iam_policy_document.fe_deploy.json
}
