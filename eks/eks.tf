# EKS 클러스터 + 관리형 노드 그룹 — 커뮤니티 EKS 모듈. IRSA 활성화(파드 단위 IAM).

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "${var.project_name}-eks-seoul"
  cluster_version = var.eks_cluster_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true
  # 클러스터 생성자(Apply 주체)에 admin — 미설정 시 kubectl에서 Forbidden 가능
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    puppytalk_main = {
      name         = "puppytalk-mng"
      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      # Cluster Autoscaler 발견용 ASG 태그 (IRSA는 irsa.tf)
      tags = {
        "k8s.io/cluster-autoscaler/enabled"                       = "true"
        "k8s.io/cluster-autoscaler/${var.project_name}-eks-seoul" = "owned"
      }
    }
  }

  tags = {
    Project    = var.project_name
    managed-by = "terraform"
  }
}
