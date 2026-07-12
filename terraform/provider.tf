terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
  }
}

# 모든 리소스에 공통 부착되는 태그 — 비용 할당·거버넌스·소유 추적.
# 리소스별 tags(Name 등)와 병합되며, 리소스 태그가 동일 키를 덮어씀.
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# 기본 리전 (서울)
provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# CloudFront 인증서용 리전 (미국 버지니아)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}