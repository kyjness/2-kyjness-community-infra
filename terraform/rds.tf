# 관리형 PostgreSQL(RDS). 단일 EC2 DB를 대체하는 운영 등급 데이터 계층.
# data 티어 프라이빗 서브넷에 배치(인터넷 격리), ECS 태스크에서만 5432 접근.
# 마스터 비밀번호는 SSM에도 저장된 var.db_master_password 재사용(ssm.tf).

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-subnets"
  subnet_ids = [aws_subnet.private_data_1.id, aws_subnet.private_data_2.id]

  tags = { Name = "${var.project_name}-rds-subnets" }
}

resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage # 스토리지 오토스케일 상한
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = var.db_master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.rds_multi_az # 대기 인스턴스 자동 페일오버(HA)

  backup_retention_period      = var.rds_backup_retention_days
  performance_insights_enabled = true
  auto_minor_version_upgrade   = true
  deletion_protection          = var.rds_deletion_protection
  skip_final_snapshot          = var.rds_skip_final_snapshot

  tags = { Name = "${var.project_name}-postgres" }
}
