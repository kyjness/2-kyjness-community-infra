# VPC 엔드포인트 — 프라이빗 ECS가 이미지 pull·시크릿 조회·로그 전송을 NAT/인터넷 없이 AWS 백본으로.
# S3는 Gateway(무료), ECR/Logs/SSM은 Interface(ENI). NAT 비용·노출 감소 + 격리 강화.

# Interface 엔드포인트용 SG: ECS 태스크에서 443만
resource "aws_security_group" "vpce" {
  name   = "${var.project_name}-vpce-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "HTTPS from ECS tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  tags = { Name = "${var.project_name}-vpce-sg" }
}

# S3 Gateway 엔드포인트 — ECR 레이어 blob(S3)·미디어 버킷 접근. 프라이빗 라우트 테이블에 연결.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app_1.id,
    aws_route_table.private_app_2.id,
    aws_route_table.private_data.id,
  ]

  tags = { Name = "${var.project_name}-vpce-s3" }
}

# Interface 엔드포인트 — ECR(api/dkr)·CloudWatch Logs·SSM. private_dns로 기본 도메인 그대로 사용.
locals {
  interface_vpce_services = {
    ecr_api = "com.amazonaws.${var.region}.ecr.api"
    ecr_dkr = "com.amazonaws.${var.region}.ecr.dkr"
    logs    = "com.amazonaws.${var.region}.logs"
    ssm     = "com.amazonaws.${var.region}.ssm"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_vpce_services

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-vpce-${each.key}" }
}
