# 미디어 파일 저장용 S3 버킷
resource "aws_s3_bucket" "media" {
  bucket = "${var.project_name}-media-bucket"
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