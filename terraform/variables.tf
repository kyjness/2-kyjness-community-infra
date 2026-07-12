variable "project_name" {
  type        = string
  default     = "puppytalk"
  description = "리소스 Name 태그·이름 접두에 공통 사용"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "domain_name" {
  type    = string
  default = "puppytalk.shop"
}

# EC2 user_data에서 postgres 비밀번호로 사용 + SSM SecureString(ssm.tf)으로 ECS에 주입
variable "db_master_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL postgres 사용자 비밀번호"
}

variable "jwt_secret_key" {
  type        = string
  sensitive   = true
  description = "백엔드 JWT 서명 키. 32자 이상 랜덤 문자열 (SSM SecureString으로 ECS에 주입)"
}

# --- RDS (관리형 PostgreSQL, rds.tf) ---
variable "rds_engine_version" {
  type        = string
  default     = "15.7"
  description = "RDS PostgreSQL 엔진 버전"
}

variable "rds_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS 인스턴스 클래스"
}

variable "rds_allocated_storage" {
  type        = number
  default     = 20
  description = "초기 스토리지(GB)"
}

variable "rds_max_allocated_storage" {
  type        = number
  default     = 100
  description = "스토리지 오토스케일 상한(GB)"
}

variable "rds_multi_az" {
  type        = bool
  default     = true
  description = "Multi-AZ 대기 인스턴스(자동 페일오버)"
}

variable "rds_backup_retention_days" {
  type        = number
  default     = 7
  description = "자동 백업 보관 일수"
}

variable "rds_database_name" {
  type        = string
  default     = "puppytalk"
  description = "초기 생성 DB 이름"
}

variable "rds_master_username" {
  type        = string
  default     = "postgres"
  description = "RDS 마스터 사용자"
}

variable "rds_deletion_protection" {
  type        = bool
  default     = false
  description = "삭제 보호 (운영 적용 시 true 권장)"
}

variable "rds_skip_final_snapshot" {
  type        = bool
  default     = true
  description = "삭제 시 최종 스냅샷 생략 여부 (운영은 false 권장)"
}

# --- ElastiCache (관리형 Redis, elasticache.tf) ---
variable "elasticache_engine_version" {
  type        = string
  default     = "7.1"
  description = "ElastiCache Redis 엔진 버전"
}

variable "elasticache_node_type" {
  type        = string
  default     = "cache.t3.micro"
  description = "ElastiCache 노드 타입"
}

variable "elasticache_num_nodes" {
  type        = number
  default     = 2
  description = "노드 수 (primary + replica). 자동 페일오버에는 2 이상 필요"
}

# GitHub Actions OIDC: IAM Role Trust의 sub 클레임 (해당 레포 워크플로만 Assume 허용)
variable "github_fe_oidc_subject" {
  type        = string
  default     = "repo:kyjness/2-kyjness-community-fe:*"
  description = "token.actions.githubusercontent.com:sub StringLike 패턴 (브랜치·환경 제한 시 :ref:refs/heads/main 등으로 좁힘)"
}

variable "github_be_oidc_subject" {
  type        = string
  default     = "repo:kyjness/2-kyjness-community-be:*"
  description = "BE 레포 GitHub Actions OIDC sub 패턴 (ECR push·ECS 배포 롤 Assume 허용 대상)"
}

# --- ECS 서비스 오토스케일 (Application Auto Scaling) ---
variable "ecs_service_min_capacity" {
  type        = number
  default     = 1
  description = "ECS be 서비스 desired_count 하한"
}

variable "ecs_service_max_capacity" {
  type        = number
  default     = 10
  description = "ECS be 서비스 desired_count 상한 (Fargate 계정 한도 내에서 조정)"
}

variable "ecs_autoscaling_cpu_target" {
  type        = number
  default     = 70
  description = "ECS 서비스 CPU 목표 추적 비율(%)"
}
