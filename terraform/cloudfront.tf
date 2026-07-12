# AWS 관리형 캐시 정책 — 정적 자산(S3 GET)에 최적. legacy forwarded_values 대신 사용:
# gzip/brotli 압축 협상 + 권장 캐시키(쿼리·쿠키 제외)를 AWS가 관리.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# CloudFront OAC (S3 접근 통제 설정)
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront 배포 설정
resource "aws_cloudfront_distribution" "frontend" {
  # [원본 1] 프론트엔드 S3 연결
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "FrontendS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  # [원본 2] 미디어 S3 연결
  origin {
    domain_name              = aws_s3_bucket.media.bucket_regional_domain_name
    origin_id                = "MediaS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  # [동작 1] 기본 경로 (프론트엔드 리액트 앱 서빙)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "FrontendS3"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # [동작 2] /media/* 경로 (미디어 S3 서빙)
  ordered_cache_behavior {
    path_pattern           = "/media/*"
    target_origin_id       = "MediaS3"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # SPA 라우팅 (F5 새로고침 에러 방지).
  # 주의: custom_error_response는 배포(distribution) 전역이라 /media/* 의 S3 403/404도
  # index.html(200)로 응답된다 — 깨진 이미지 URL이 HTML을 반환. 단일 SPA+미디어 구성에서
  # 감수하는 트레이드오프(경로별 에러 매핑 불가). 분리가 필요하면 미디어를 별도 배포/서브도메인으로.
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
    acm_certificate_arn      = aws_acm_certificate_validation.cf_cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# 도메인 A 레코드 (Route 53 연결)
resource "aws_route53_record" "frontend" {
  zone_id = aws_route53_zone.selected.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}