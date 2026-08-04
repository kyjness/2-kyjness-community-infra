# CloudFront가 붙일 인증서. apex 하나면 된다 —
# api 서브도메인은 Lightsail 위의 Caddy가 Let's Encrypt로 직접 발급·갱신한다.
resource "aws_acm_certificate" "site" {
  provider          = aws.us_east_1 # CloudFront 인증서는 반드시 us-east-1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = 60
}

# 검증은 NS 위임이 끝나야 통과한다 — 위임 전에 apply하면 여기서 멈춘 채 대기한다.
resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
