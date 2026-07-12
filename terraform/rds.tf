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

  backup_retention_period = var.rds_backup_retention_days
  # Performance Insights는 버스터블 micro 클래스(db.t3.micro 등)에서 미지원 → 기본 off,
  # 클래스 상향 시 var로 활성화. (기본 인스턴스가 micro라 apply 에러 방지)
  performance_insights_enabled = var.rds_performance_insights_enabled
  auto_minor_version_upgrade   = true
  deletion_protection          = var.rds_deletion_protection
  skip_final_snapshot          = var.rds_skip_final_snapshot
  # skip_final_snapshot=false(운영)일 때 필요 — 삭제 시 최종 스냅샷 이름
  final_snapshot_identifier = "${var.project_name}-postgres-final"

  tags = { Name = "${var.project_name}-postgres" }
}
