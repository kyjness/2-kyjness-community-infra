# CloudFront용 인증서(us-east-1). apex + *.domain (api 서브도메인용 별칭 추가 시 동일 인증서 활용 가능)
resource "aws_acm_certificate" "cf_cert" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cf_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.selected.zone_id
}

resource "aws_acm_certificate_validation" "cf_cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cf_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# -----------------------------------------------------------------------------
# ALB(백엔드) HTTPS — ap-northeast-2 ACM 전용 (CloudFront용 us-east-1 인증서와 분리)
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "alb_api" {
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "alb_api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb_api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  zone_id         = aws_route53_zone.selected.zone_id
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
}

resource "aws_acm_certificate_validation" "alb_api" {
  certificate_arn         = aws_acm_certificate.alb_api.arn
  validation_record_fqdns = [for r in aws_route53_record.alb_api_cert_validation : r.fqdn]
}
