# 미디어 파일 저장용 S3 버킷
resource "aws_s3_bucket" "media" {
  bucket        = "${var.project_name}-media-bucket"
  force_destroy = true
}

# 미디어 버킷 퍼블릭 접근 차단 (보안 강화)
resource "aws_s3_bucket_public_access_block" "media_block" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 미디어 버킷 정책 (CloudFront 대문을 통해서만 읽기 허용)
resource "aws_s3_bucket_policy" "media_policy" {
  bucket = aws_s3_bucket.media.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.media.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}
# confirm되지 않은 presigned 업로드 잔존물 GC.
# pending/ 객체는 DB 행이 없어 앱 sweeper가 지울 수 없다 — presign TTL 15분·업로드 직후
# confirm 계약상 1일 넘게 남은 pending은 전부 미완료 잔존물이므로 버킷 수명주기로 만료.
# (dev/CI는 minio-init의 mc ilm 등가 규칙 — 저장소 수명주기는 저장소 계층 책임)
resource "aws_s3_bucket_lifecycle_configuration" "media_pending_gc" {
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
}
