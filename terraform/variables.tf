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

# EC2 user_data에서 postgres 비밀번호로 사용
variable "db_master_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL postgres 사용자 비밀번호"
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
