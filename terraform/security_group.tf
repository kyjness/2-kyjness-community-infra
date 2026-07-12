# ALB: 인터넷 → 80(HTTPS로 301)·443(종단 TLS) 수신 (ECS는 ALB 경유만 허용)
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-alb-sg-"
  description = "ALB inbound HTTP redirect + HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Fargate: 앱 포트는 ALB SG에서만 허용 (순환 참조 없음: ecs_sg → alb_sg 단방향)
resource "aws_security_group" "ecs_sg" {
  name   = "${var.project_name}-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "App HTTP from ALB only"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB(RDS)·Redis(ElastiCache) SG는 각각 rds.tf·elasticache.tf에 정의 (data 티어, ecs_sg에서만 접근).