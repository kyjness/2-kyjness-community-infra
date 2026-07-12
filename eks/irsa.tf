# Cluster Autoscaler용 IRSA — kube-system/cluster-autoscaler SA에 이 역할 ARN을 주입(Helm/매니페스트).
# 노드 그룹 ASG 태그(k8s.io/cluster-autoscaler/*)는 eks.tf에서 설정.

module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.project_name}-cluster-autoscaler"

  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = {
    Project    = var.project_name
    managed-by = "terraform"
  }
}
