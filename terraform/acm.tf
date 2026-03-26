# 1. 서울 리전 인증서 (ALB 백엔드용: api.puppytalk.shop 커버)
resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"] # 서브도메인 모두 허용
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
}

# 2. 버지니아 북부 리전 인증서 (CloudFront 프론트엔드용: puppytalk.shop 커버)
resource "aws_acm_certificate" "cf_cert" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
}

# 3. DNS 검증 레코드 (동일한 도메인이므로 서울 리전 DVO만 사용해도 둘 다 검증됨)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.selected.zone_id
}

# 4. 검증 완료 대기 (서울 및 미국)
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
resource "aws_acm_certificate_validation" "cf_cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cf_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}