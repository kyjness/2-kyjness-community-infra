# 호스팅 영역. 생성 후 출력되는 네임서버 4개를 도메인 등록업체에 위임해야
# ACM 검증·CloudFront·Caddy의 인증서 발급이 전부 동작한다.
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# apex → 프론트(CloudFront). CNAME을 못 쓰는 apex라 ALIAS로 붙인다.
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# api → 백엔드(Lightsail 고정 IP). 이 레코드가 먼저 살아 있어야 Caddy가 api 도메인
# 인증서를 HTTP-01로 발급받을 수 있다.
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_lightsail_static_ip.app.ip_address]
}
