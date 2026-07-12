output "cluster_name" {
  description = "EKS 클러스터 이름 (aws eks update-kubeconfig --name)"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "cluster_autoscaler_irsa_role_arn" {
  description = "Cluster Autoscaler SA에 주입할 IRSA 역할 ARN"
  value       = module.cluster_autoscaler_irsa.iam_role_arn
}
