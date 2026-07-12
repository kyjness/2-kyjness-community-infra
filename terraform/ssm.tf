# 애플리케이션 시크릿: SSM Parameter Store(SecureString).
# ECS 태스크 정의는 값을 직접 담지 않고 이 파라미터 ARN을 secrets.valueFrom 으로 참조 →
# 시크릿이 태스크 정의 JSON·ECS 콘솔/API에 평문 노출되지 않음.
# Secrets Manager 대비 SSM Parameter Store가 무료 티어로 충분(회전 요구 없음)하여 채택.

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${var.project_name}/jwt_secret_key"
  description = "백엔드 JWT 서명 키 (프로덕션 가드: placeholder·32자 미만 거부)"
  type        = "SecureString"
  value       = var.jwt_secret_key
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/db_password"
  description = "RDS PostgreSQL 마스터 비밀번호 (var.db_master_password와 동일 값)"
  type        = "SecureString"
  value       = var.db_master_password
}
