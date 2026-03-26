# 1. 기존 Route 53 호스팅 영역 정보 불러오기
data "aws_route53_zone" "selected" {
  name         = "puppytalk.shop"
  private_zone = false
}

# 2. 백엔드 API용 A 레코드 (api.puppytalk.shop -> ALB)
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}