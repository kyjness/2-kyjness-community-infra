# -----------------------------------------------------------------------------
# execution_role: ECR 이미지 pull, CloudWatch Logs 전송 등 "태스크 인프라"용.
# task_role: 컨테이너 프로세스(boto3 등)가 호출하는 AWS API 권한 — AK/SK 환경변수 불필요.
# AK/SK 주입은 유출·로그 노출·과도 권한 위험이 있음; Task Role은 세션 자격·최소 ARN으로 완화.
# -----------------------------------------------------------------------------

# ECS Task Execution Role: ECS가 컨테이너를 실행할 때 사용하는 역할
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# 표준 권한 연결 (이미지 다운로드 및 로그 기록 권한)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ecsTaskExecutionRole에 로그 그룹 생성 권한 추가
resource "aws_iam_role_policy" "ecs_task_execution_logs_policy" {
  name = "${var.project_name}-ecs-logs-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# 백엔드 애플리케이션 전용 Task Role (S3 미디어 버킷만 허용 — Resource 와일드카드 금지)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "be_s3_policy" {
  name        = "${var.project_name}-be-s3-media-policy"
  description = "BE 컨테이너: media 버킷 객체 CRUD 및 버킷 목록만 허용"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListMediaBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.media.arn
      },
      {
        Sid    = "ObjectRWMediaBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${aws_s3_bucket.media.arn}/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.be_s3_policy.arn
}

# SNS 발행은 앱(boto3)이 Task Role로 수행 — execution_role 이 아님 (sns.tf 정책 재사용)
resource "aws_iam_role_policy_attachment" "ecs_task_role_sns" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}