# 백엔드용 이미지 저장소 생성
resource "aws_ecr_repository" "be" {
  name                 = "${var.project_name}-be"
  image_tag_mutability = "MUTABLE" # 같은 태그(latest)로 덮어쓰기 허용

  image_scanning_configuration {
    scan_on_push = true # 이미지 올릴 때 보안 취약점 자동 검사
  }
}