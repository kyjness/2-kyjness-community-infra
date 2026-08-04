# 백엔드가 S3에 접근할 때 쓰는 자격.
#
# 왜 인스턴스 롤이 아니라 IAM 유저인가: Lightsail 인스턴스에는 IAM 롤을 붙일 수 없고,
# 앱의 프로덕션 가드(app/core/config.py)도 AWS_ACCESS_KEY_ID·AWS_SECRET_ACCESS_KEY가
# 채워져 있어야 기동한다. 권한은 미디어 버킷의 media/ 아래로만 좁힌다.
#
# 액세스 키는 terraform이 만들지 않는다 — 만들면 시크릿이 tfstate에 평문으로 남는다.
# apply 후 아래 명령으로 직접 발급해 .env.prod 에만 넣는다:
#   aws iam create-access-key --user-name <app_iam_user_name 출력값>

resource "aws_iam_user" "app" {
  name = "${var.project_name}-app"
}

data "aws_iam_policy_document" "app_media" {
  statement {
    sid    = "MediaObjectsReadWrite"
    effect = "Allow"
    actions = [
      # presigned POST로 올라온 pending 객체를 확인(Head=GetObject)하고,
      # 영구 경로로 복사(Get+Put)한 뒤 원본을 지운다(promote_pending_object).
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${aws_s3_bucket.media.arn}/media/*"]
  }

  # 매일 도는 pg_dump 백업(서버의 backup_db.sh)이 같은 자격으로 올린다.
  # 쓰기만 필요하다 — 복구할 때는 사람이 콘솔·개인 자격으로 내려받는다.
  statement {
    sid       = "BackupUpload"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.media.arn}/backup/*"]
  }
}

resource "aws_iam_user_policy" "app_media" {
  name   = "${var.project_name}-app-media"
  user   = aws_iam_user.app.name
  policy = data.aws_iam_policy_document.app_media.json
}
