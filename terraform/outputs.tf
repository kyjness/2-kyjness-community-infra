output "ecr_be_repository_url" {
  description = "백엔드 ECR 리포지토리 URL (ECS 태스크 정의 image 소스)"
  value       = aws_ecr_repository.be.repository_url
}

output "s3_media_bucket_id" {
  description = "미디어 S3 버킷 ID (terraform/media.tf aws_s3_bucket.media)"
  value       = aws_s3_bucket.media.id
}

output "db_server_public_ip" {
  description = "DB/Redis EC2 퍼블릭 IP"
  value       = aws_instance.db_server.public_ip
}

output "db_server_private_ip" {
  description = "DB/Redis EC2 프라이빗 IP (ECS 태스크 env 등)"
  value       = aws_instance.db_server.private_ip
}

output "github_actions_fe_deploy_role_arn" {
  description = "FE GitHub Actions OIDC용 IAM Role ARN (configure-aws-credentials role-to-assume)"
  value       = aws_iam_role.fe_github_actions.arn
}

output "github_actions_be_deploy_role_arn" {
  description = "BE GitHub Actions OIDC용 IAM Role ARN (ECR push·ECS 배포 role-to-assume)"
  value       = aws_iam_role.be_github_actions.arn
}
