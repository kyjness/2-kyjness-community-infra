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

  container_definitions = jsonencode([{
    name      = "${var.project_name}-be-container"
    image     = "${aws_ecr_repository.be.repository_url}:latest"
    essential = true
    
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]

    environment = [
      # DB 및 Redis 접속 정보
      { name = "DB_HOST",     value = aws_instance.db_server.private_ip },
      { name = "DB_PORT",     value = "5432" },
      { name = "DB_USER",     value = "postgres" },
      { name = "DB_PASSWORD", value = var.db_master_password },
      { name = "DB_NAME",     value = "puppytalk" },
      { name = "REDIS_URL",   value = "redis://${aws_instance.db_server.private_ip}:6379/0" },

      # S3 관련 설정 (에러 해결 핵심 포인트!)
      { name = "STORAGE_BACKEND",       value = "s3" },
      { name = "S3_BUCKET_NAME",        value = aws_s3_bucket.media.id },
      { name = "AWS_REGION",            value = var.region },
      
      # 💡 [추가] S3 접근 권한 키 주입
      { name = "AWS_ACCESS_KEY_ID",     value = var.aws_access_key },
      { name = "AWS_SECRET_ACCESS_KEY", value = var.aws_secret_key },

      # 💡 [수정] 이미지 조회 주소를 CloudFront 도메인으로 변경
      { name = "S3_PUBLIC_BASE_URL",    value = "https://${var.domain_name}/media" },

      # 💡 [추가] 보안 및 도메인 설정
      { name = "CORS_ORIGINS",          value = "https://${var.domain_name},http://localhost:5173" },
      { name = "JWT_SECRET_KEY",        value = "your-very-secret-key-change-me" } # 실무에선 시크릿 매니저 권장
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

  # 배포 시 새 태스크가 뜰 때까지 기존 태스크 유지
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.be.arn
    container_name   = "${var.project_name}-be-container"
    container_port   = 8000
  }
}