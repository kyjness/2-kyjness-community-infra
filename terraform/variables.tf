variable "project_name" {
  default = "puppytalk"
}

variable "region" {
  default = "ap-northeast-2"
}

variable "domain_name" {
  default = "puppytalk.shop"
}

# EC2 user_data에서 postgres 비밀번호로 사용
variable "db_master_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL postgres 사용자 비밀번호"
}

# 💡 [추가] S3 접근을 위한 액세스 키
variable "aws_access_key" {
  type        = string
  sensitive   = true
  description = "AWS Access Key ID for S3 storage"
}

# 💡 [추가] S3 접근을 위한 시크릿 키
variable "aws_secret_key" {
  type        = string
  sensitive   = true
  description = "AWS Secret Access Key for S3 storage"
}