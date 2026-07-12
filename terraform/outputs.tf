output "ecr_be_repository_url" {
  description = "백엔드 ECR 리포지토리 URL (ECS 태스크 정의 image 소스)"
  value       = aws_ecr_repository.be.repository_url
}

output "s3_media_bucket_id" {
  description = "미디어 S3 버킷 ID (terraform/media.tf aws_s3_bucket.media)"
  value       = aws_s3_bucket.media.id
}

output "rds_address" {
  description = "RDS PostgreSQL 엔드포인트 (ECS 태스크 DB_HOST)"
  value       = aws_db_instance.main.address
}

output "redis_primary_endpoint" {
  description = "ElastiCache Redis primary 엔드포인트 (ECS 태스크 REDIS_URL)"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "github_actions_fe_deploy_role_arn" {
  description = "FE GitHub Actions OIDC용 IAM Role ARN (configure-aws-credentials role-to-assume)"
  value       = aws_iam_role.fe_github_actions.arn
}

output "github_actions_be_deploy_role_arn" {
  description = "BE GitHub Actions OIDC용 IAM Role ARN (ECR push·ECS 배포 role-to-assume)"
  value       = aws_iam_role.be_github_actions.arn
}
