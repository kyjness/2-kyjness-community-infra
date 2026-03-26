# ECS 로그를 저장할 그룹 생성
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7 # 로그 보관 기간 (비용 절감을 위해 7일 설정)
}