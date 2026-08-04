# apex 도메인 하나로 정적 프론트와 업로드 이미지를 함께 서빙한다.
#   /          → 프론트 S3 (SPA)
#   /media/*   → 미디어 S3 (백엔드가 S3_PUBLIC_BASE_URL=https://<domain>/media 로 링크를 만든다)
# CloudFront는 월 1TB 전송·1천만 요청이 상시 무료라 이 규모에서는 사실상 0원이다.

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "FrontendS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  origin {
    domain_name              = aws_s3_bucket.media.bucket_regional_domain_name
    origin_id                = "MediaS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]
  # PriceClass_200 = 아시아 포함, 남미·오세아니아 제외. 국내 조회가 대부분이라 충분하다.
  price_class = "PriceClass_200"

  default_cache_behavior {
    target_origin_id       = "FrontendS3"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern           = "/media/*"
    target_origin_id       = "MediaS3"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # SPA 새로고침(F5) 대응. 주의: custom_error_response는 배포 전역이라 /media/* 의 404도
  # index.html(200)로 응답된다 — 깨진 이미지 URL이 HTML을 반환한다. 미디어를 별도 배포로
  # 떼면 해결되지만, 배포 하나로 도메인·인증서·비용을 아끼는 쪽을 택했다.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
