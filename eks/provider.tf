# EKS 대안 트랙 — terraform/(ECS)과 분리된 별도 root(자체 state·apply).
# ECS가 1차 아키텍처, 여기는 "동일 앱을 EKS로 운영한다면" 설계. 미적용(비용 0).

terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}
