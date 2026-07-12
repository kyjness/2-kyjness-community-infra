# 1. ECS 클러스터
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# 2. 작업 정의 (FastAPI 컨테이너 환경 설정)
resource "aws_ecs_task_definition" "be" {
  family                   = "${var.project_name}-be-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "${var.project_name}-be-container"
    image     = "${aws_ecr_repository.be.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]

    environment = [
      # DB 및 Redis 접속 정보 (비밀번호는 secrets로 분리)
      { name = "DB_HOST", value = aws_db_instance.main.address },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_USER", value = var.rds_master_username },
      { name = "DB_NAME", value = var.rds_database_name },
      { name = "REDIS_URL", value = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379/0" },

      # S3 관련 설정
      { name = "STORAGE_BACKEND", value = "s3" },
      { name = "S3_BUCKET_NAME", value = aws_s3_bucket.media.id },
      { name = "AWS_REGION", value = var.region },

      # 이미지 조회 주소를 CloudFront 도메인으로 변경
      { name = "S3_PUBLIC_BASE_URL", value = "https://${var.domain_name}/media" },

      # 보안 및 도메인 설정
      { name = "CORS_ORIGINS", value = "https://${var.domain_name},http://localhost:5173" },
      { name = "SNS_TOPIC_ARN", value = aws_sns_topic.notifications.arn },
    ]

    # 시크릿은 SSM SecureString에서 주입 — 태스크 정의에 평문 미노출 (ssm.tf)
    secrets = [
      { name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn },
      { name = "JWT_SECRET_KEY", valueFrom = aws_ssm_parameter.jwt_secret.arn },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 3. ECS 서비스
resource "aws_ecs_service" "be" {
  name            = "${var.project_name}-be-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.be.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 60

  # 배포 시 새 태스크가 뜰 때까지 기존 태스크 유지
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  load_balancer {
    target_group_arn = aws_lb_target_group.be_tg.arn
    container_name   = "${var.project_name}-be-container"
    container_port   = 8000
  }

  # 태스크는 프라이빗 app 서브넷에 배치 — 퍼블릭 IP 없음. 인바운드는 ALB만, egress는 NAT 경유.
  network_configuration {
    subnets          = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_lb_listener.be_http,
    aws_lb_listener.be_https,
  ]

  # Application Auto Scaling(ecs_autoscaling.tf)이 desired_count를 조절하므로 Terraform은 이후 갱신 무시
  lifecycle {
    ignore_changes = [desired_count]
  }
}