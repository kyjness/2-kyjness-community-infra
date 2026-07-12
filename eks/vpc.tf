# EKS 전용 네트워크 — 커뮤니티 VPC 모듈로 간결하게. 프라이빗 노드 + 퍼블릭 ALB용 서브넷.
# k8s 서브넷 태그(role/elb·internal-elb)로 AWS Load Balancer Controller가 서브넷 자동 발견.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-eks-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}c"]
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # 비용 절감(설계·미적용). 운영 HA는 AZ별 NAT로.
  enable_dns_hostnames = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  tags = {
    Project    = var.project_name
    managed-by = "terraform"
  }
}
