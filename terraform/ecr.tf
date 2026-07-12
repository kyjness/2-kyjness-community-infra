# 백엔드용 이미지 저장소 생성
resource "aws_ecr_repository" "be" {
  name                 = "${var.project_name}-be"
  image_tag_mutability = "MUTABLE" # 같은 태그(latest)로 덮어쓰기 허용
  force_delete         = true      # 리포지토리 삭제 시 남아있는 이미지도 함께 삭제

  image_scanning_configuration {
    scan_on_push = true # 이미지 올릴 때 보안 취약점 자동 검사
  }
}

# 라이프사이클 정책 — :latest 덮어쓰기로 쌓이는 dangling(untagged) 이미지와
# 오래된 이미지를 자동 만료해 스토리지 비용·목록 팽창을 억제.
resource "aws_ecr_lifecycle_policy" "be" {
  repository = aws_ecr_repository.be.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "untagged 이미지는 1일 후 만료 (:latest 재푸시로 생긴 dangling 정리)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "가장 최근 10개 이미지만 보관"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      },
    ]
  })
}