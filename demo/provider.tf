terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
  }

  # 원격 상태를 두지 않는다(로컬 tfstate). 이 root는 혼자 쓰는 데모용이고 시크릿을
  # 담지 않으므로 S3+DynamoDB 잠금(../terraform/backend.tf)까지 갈 이유가 없다.
}

locals {
  common_tags = {
    # 비용 할당 태그 — Billing 콘솔에서 이 키를 활성화해야 프로젝트별 비용이 갈린다.
    # 활성화 후 24시간이 지나야 집계가 시작된다.
    Project     = var.project_name
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# CloudFront가 붙일 인증서는 반드시 us-east-1에 있어야 한다.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}
