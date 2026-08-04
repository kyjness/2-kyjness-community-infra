# 업로드 이미지 저장소. 앱은 MinIO가 아니라 실제 S3를 쓴다 — presigned POST의 URL이
# S3_ENDPOINT_URL 기준으로 만들어져 브라우저에게 그대로 전달되므로(app/infra/storage.py),
# 내부 전용 엔드포인트를 두면 업로드가 깨진다.
resource "aws_s3_bucket" "media" {
  bucket        = "${var.project_name}-media"
  force_destroy = true # 데모 — destroy 시 남은 객체까지 정리
}

# 버킷은 비공개다. 읽기는 CloudFront(OAC)만, 쓰기는 presigned POST(서명)만 통과한다.
resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "media" {
  bucket = aws_s3_bucket.media.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.media.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.site.arn }
      }
    }]
  })
}

# 브라우저가 S3로 직접 POST(presigned)하므로 CORS가 없으면 업로드가 프리플라이트에서 막힌다.
# 서명이 인증을 담당하므로 오리진만 우리 프론트로 좁히면 된다.
resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  cors_rule {
    allowed_origins = ["https://${var.domain_name}"]
    allowed_methods = ["POST", "GET", "HEAD"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag", "Location"]
    max_age_seconds = 3000
  }
}

# confirm되지 않은 presigned 업로드 잔존물 GC — pending/ 객체는 DB 행이 없어 앱 sweeper가
# 지울 수 없다. presign TTL 15분 계약상 하루 넘게 남은 pending은 전부 미완료 잔존물이다.
# (ADR 0010: 저장소 수명주기는 저장소 계층 책임. dev는 minio-init의 mc ilm 규칙이 등가)
resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "expire-pending-uploads"
    status = "Enabled"

    filter {
      prefix = "media/pending/"
    }

    expiration {
      days = 1
    }
  }

  # DB 백업(backup_db.sh)은 14일치만 둔다 — 데모라 그 이상 보관할 이유가 없고,
  # 방치하면 매일 한 개씩 쌓여 스토리지 비용이 조용히 늘어난다.
  rule {
    id     = "expire-db-backups"
    status = "Enabled"

    filter {
      prefix = "backup/"
    }

    expiration {
      days = 14
    }
  }
}
