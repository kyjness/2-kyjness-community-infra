# apply 직후 필요한 값들. `terraform output` 으로 확인한다.

output "name_servers" {
  description = "도메인 등록업체에 위임할 네임서버 4개. 이걸 먼저 해야 ACM 검증이 끝난다"
  value       = aws_route53_zone.main.name_servers
}

output "server_ip" {
  description = "백엔드 고정 IP (api 레코드가 가리키는 곳)"
  value       = aws_lightsail_static_ip.app.ip_address
}

output "ssh_command" {
  description = "서버 접속 명령"
  value       = "ssh -i <개인키> ec2-user@${aws_lightsail_static_ip.app.ip_address}"
}

output "media_bucket" {
  description = ".env.prod 의 S3_BUCKET_NAME"
  value       = aws_s3_bucket.media.bucket
}

output "s3_public_base_url" {
  description = ".env.prod 의 S3_PUBLIC_BASE_URL (CloudFront /media/* 경유)"
  value       = "https://${var.domain_name}/media"
}

output "app_iam_user_name" {
  description = "액세스 키를 발급할 대상: aws iam create-access-key --user-name <이 값>"
  value       = aws_iam_user.app.name
}

output "frontend_bucket" {
  description = "FE 워크플로의 sync 대상 버킷"
  value       = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  description = "FE 워크플로의 CloudFront 무효화 대상 (GitHub Secret)"
  value       = aws_cloudfront_distribution.site.id
}

output "fe_github_actions_role_arn" {
  description = "FE 워크플로가 AssumeRole 할 롤 ARN (GitHub Secret)"
  value       = aws_iam_role.fe_github_actions.arn
}
