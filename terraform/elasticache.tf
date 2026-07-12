# 관리형 Redis(ElastiCache). EC2의 단일 Redis를 대체.
# data 티어 프라이빗 서브넷, ECS 태스크에서만 6379. primary + replica(자동 페일오버·Multi-AZ).

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-redis-subnets"
  subnet_ids = [aws_subnet.private_data_1.id, aws_subnet.private_data_2.id]
}

resource "aws_security_group" "redis" {
  name   = "${var.project_name}-redis-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Redis from ECS tasks only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-redis-sg" }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-redis"
  description          = "PuppyTalk Redis (cache + Celery broker)"

  engine         = "redis"
  engine_version = var.elasticache_engine_version
  node_type      = var.elasticache_node_type
  port           = 6379

  num_cache_clusters         = var.elasticache_num_nodes # primary + replica
  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  # transit(in-transit TLS)를 켜면 REDIS_URL이 rediss:// + auth_token 전제가 됨 → 앱 설정 연동 필요.
  transit_encryption_enabled = false

  tags = { Name = "${var.project_name}-redis" }
}
